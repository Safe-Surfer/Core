# Ingress and cert setup
A Kubernetes [ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) allows HTTP(s) traffic to reach the services in the cluster using a single external IP address. To run Safe Surfer in production, you may need to create one at some point.

## Ingress Controller
This chart creates standard Kubernetes Ingress resources and is compatible with any ingress controller. Each ingress has a configurable `class` field and an `annotations` map, allowing you to use controller-specific annotations as needed.

`api.realIPHeader` and `categorizer.adminApp.realIPHeader` default to `X-Forwarded-For`, which is the header Traefik sends. Leave them at that unless the proxy in front of the cluster uses a different header. A wrong header is a security problem when IP linking is on.

## Example: Installing Traefik
[Traefik](https://doc.traefik.io/traefik/) is the ingress controller used with this chart. Install it with Helm:

```sh
helm repo add traefik https://traefik.github.io/charts
kubectl create namespace traefik
helm install traefik traefik/traefik --namespace traefik
```

A release named `traefik` creates an IngressClass named `traefik`. Set each Safe Surfer ingress `class` or `ingressClass` to `traefik`. Run `kubectl -n traefik get svc` until the Service has an external IP.

### Restricting source IPs
The chart does not read `whitelistSourceRange`. To allow only some client addresses, add a Traefik [IP allow list](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/ipallowlist/) middleware with `customManifests`, then attach it to the ingress.

The middleware reference is `<namespace>-<name>@kubernetescrd`. This example allows one address to the API. Put the middleware in the same namespace as the ingress.

```yaml
api:
  ingress:
    class: traefik
    annotations:
      traefik.ingress.kubernetes.io/router.middlewares: default-api-ipallowlist@kubernetescrd
customManifests:
- apiVersion: traefik.io/v1alpha1
  kind: Middleware
  metadata:
    name: api-ipallowlist
    namespace: default
  spec:
    ipAllowList:
      sourceRange:
      - 203.0.113.10/32
```

Several middlewares are separated by commas. A rate-limit middleware and an allow list look like this on the annotation: `default-api-ratelimit@kubernetescrd,default-api-ipallowlist@kubernetescrd`. `api.adminIngress` uses `api.ingress.class` and its own `annotations`. `dns.clickhoused.internal.frontend.http` uses `ingressClass` and `ingressAnnotations`.

DNS feeds serve gRPC. Traefik does not serve that on a standard Ingress. Leave `feeds.dns.*.ingress.enabled` false and add an `IngressRoute` through `customManifests` with `scheme: h2c` and `tls.secretName` set to the certificate secret.

At this point, it's recommended to decide on a domain to use for the Safe Surfer deployment. It can be a subdomain of your own domain, or whatever you wish. Then, create a wildcard DNS entry for any subdomains of that domain that points to your new external IP.

For example, if your domain was `ss.example.com` and your external IP was `0.0.0.0`, you'd create a DNS entry for `*.ss.example.com` pointing to `0.0.0.0`. Doing it this way is optional, but does save you some time. You can also have completely different domains for each Safe Surfer deployment.

## Enabling TLS
Various parts of the Safe Surfer deployment may require you to enable TLS. There are a few different ways to do this:
- If [cert manager](https://cert-manager.io/) is installed in the cluster, you can use the HTTP01 challenge mechanism to automatically generate, renew, and use a certificate from letsencrypt.
- Supply any custom cert/key pair.
- Supply the name of a secret containing the `tls.crt` and `tls.key` files. You can use this to set up a letsencrypt cert using [DNS01 validation](https://cert-manager.io/docs/configuration/acme/dns01/) with cert-manager.

### Installing cert-manager
The full instructions are [here](https://cert-manager.io/docs/installation/), but in most cases all you need is `kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.0/cert-manager.yaml`.

This command will install cert manager to the `cert-manager` namespace. Run `kubectl -n cert-manager get pods` until you see a result like the following:

```
NAME                                      READY   STATUS    RESTARTS   AGE
cert-manager-99bb69456-jbjbc              1/1     Running   0          15s
cert-manager-cainjector-ffb4747bb-6fpbw   1/1     Running   0          16s
cert-manager-webhook-545bd5d7d8-7sd86     1/1     Running   0          14s
```

This means cert-manager is ready to start generating certificates.

### HTTP01 method
For an ingress whose `tls` object has `http01`, leave that field at its default `true` and leave `secretName` empty:

```yaml
tls:
  http01: true
```

`secretName` wins. If it is set, the chart does not create an HTTP01 issuer, even when `http01` is still `true`.

Set the ingress `class` to `traefik`. The HTTP01 solver uses that class. Also set an email for Let's Encrypt:

```yaml
certmanager:
  letsencrypt:
    email: user@example.com
```

The chart does not read `certmanager.letsencrypt.cloudflare`. DNS01 is configured with the manifests below, not with that key.

On a single-namespace release the chart creates an `Issuer` named `<component>-cert` and a certificate secret of the same name. A deployment that sets `testFlags.legacyNames` creates a `ClusterIssuer` named `letsencrypt-prod-<component>` instead, because each component has its own namespace.

`HTTP01` is not available for `dns.doh`, `dns.dot`, `dns.doq`, or `protocolchecker`. DoH, DoT, and DoQ terminate TLS in the DNS pod, and the chart marks those certificates `noHttpSupport`. The protocol checker needs names that are not on the public internet. Use a secret for those. The block page does not use this setting either. The chart always gives it a self-signed cert-manager `Issuer` for `blockpage.domain`.

HTTP01 can also fail when cert-manager is not allowed to create the solver pod. DNS01 does not create that pod.

### Custom cert method
You can supply a custom cert for any deployment like this:

```yaml
tls:
  http01: false
  custom:
    enabled: true
    cert: |-
      -----BEGIN CERTIFICATE-----
      Your-Cert-Here
      -----END CERTIFICATE-----
    key: |-
      -----BEGIN RSA PRIVATE KEY-----
      Your-Key-Here
      -----END RSA PRIVATE KEY-----
```

### Secret name method
For an ingress, clickhoused HTTP, or the protocol checker, point `tls.secretName` at a secret that already contains `tls.crt` and `tls.key`:

```yaml
tls:
  secretName: my-tls-secret
```

`protocolchecker.tls` has no `http01` field. `secretName` is enough there. The secret has to sit in the same namespace as the workload. A multi-namespace release needs one copy of the secret in each namespace that mounts it.

DoH, DoT, and DoQ take a list, not the ingress `tls` object:

```yaml
dns:
  doh:
    tls:
    - secretName: my-doh-secret
  dot:
    tls:
    - secretName: my-dot-secret
  doq:
    tls:
    - secretName: my-doq-secret
```

Creating the certificate secret does not attach it. The list entries above are what mount it into the DNS pod.

### Using the DNS01 challenge type
[DNS01 validation](https://cert-manager.io/docs/configuration/acme/dns01/) with cert-manager has many advantages over HTTP01 validation:
- Does not require creating a pod, so works even when permissions are restrictive
- Does not require the domain to exist before the certificate can be created
- Does not require an ingress to exist for the domain of the certificate

However, it is also more difficult to configure, and the configuration depends on your authoritative DNS server. Point `secretName` at the secret cert-manager will create. `customManifests` can hold the cert-manager objects in the same values file.

For one namespace, use an `Issuer` and a `Certificate` in the release namespace. Keep the ACME account key (`privateKeySecretRef`) separate from the certificate secret. A token is enough for the Cloudflare solver. `email` on that solver is only for the older global API key.

```yaml
customManifests:
- apiVersion: v1
  kind: Secret
  metadata:
    name: cloudflare-api-token-secret
    namespace: default
  type: Opaque
  stringData:
    api-token: <API Token>
- apiVersion: cert-manager.io/v1
  kind: Issuer
  metadata:
    name: example-issuer
    namespace: default
  spec:
    acme:
      server: https://acme-v02.api.letsencrypt.org/directory
      email: user@example.com
      privateKeySecretRef:
        name: example-issuer-account
      solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token-secret
              key: api-token
        selector:
          dnsNames:
          - '*.ss.example.com'
- apiVersion: cert-manager.io/v1
  kind: Certificate
  metadata:
    name: example-cert
    namespace: default
  spec:
    secretName: my-tls-secret
    issuerRef:
      name: example-issuer
      kind: Issuer
      group: cert-manager.io
    dnsNames:
    - '*.ss.example.com'
```

Then set `tls.secretName` to `my-tls-secret`. Add any extra names to `dnsNames` on both the solver selector and the certificate.

When components run in more than one namespace, use a `ClusterIssuer` and one `Certificate` per namespace, each with the same `secretName` and `dnsNames`. The private deployment does this because `testFlags.legacyNames` gives each component its own namespace. The wildcard certificate is created once in the DNS namespace and again in the API namespace. DoH and the protocol checker get their own issuers, because their names are not covered by that wildcard. DoT can use another ACME server, such as DigiCert, with `externalAccountBinding` on the issuer. Store that key in a secret and do not put it in the guide.

For the full list of authoritative DNS providers, see the [cert-manager docs](https://cert-manager.io/docs/configuration/acme/dns01/).
