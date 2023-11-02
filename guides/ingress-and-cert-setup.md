# Ingress and cert setup
A Kubernetes [ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) allows HTTP(s) traffic to reach the services in the cluster using a single external IP address. To run Safe Surfer in production, you may need to create one at some point.

## Ingress Controller
This chart supports the Nginx ingress controller natively. If you have an existing cluster with a different ingress controller, that's ok. You can run multiple by proceeding with the rest of this guide, or choose to create your own ingress resources.

## Creating Your Own Ingress Resources
If you choose to do this, you must just reference the services created by this chart in your manifests. You also need to ensure that `api.realIPHeader` and `categorizer.adminApp.realIPHeader` are configured with a header they can use to find the source IP of the user. Failing to configure this correctly can be a security concern. Also note that any `rateLimiting` parameters are implemented using the nginx ingress controller, so will not work when it's not being used. Parameters not named `rateLimiting`, e.g. `api.accounts.signonRateLimit` are not based on nginx and will work regardless.

## Installing Nginx Ingress Controller
Nginx ingress controller is also distributed as a helm chart. Let's create a values file for it named `nginx-values.yaml`. Fill it with the following content to begin with:

```yaml
controller:
  # Create a service, which will create a new external IP. You may be charged for this.
  service:
    enabled: true
    externalTrafficPolicy: Local
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "external"
      service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
      service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
      service.beta.kubernetes.io/aws-load-balancer-proxy-protocol: "*"
  # Autoscale from 1-10.
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 10
    targetCPUUtilizationPercentage: 80
  # Enable prometheus metrics.
  metrics:
    enabled: true
  # Estimate resources, but don't apply limits yet.
  resources:
    requests:
      cpu: 100m
      memory: 90Mi
  # Enable finding the source IP from the headers.
  config:
    use-forward-headers: "true"
    compute-full-forward-for: "true"
    # On AWS, use the following
    # use-proxy-protocol: "true"
  # Don't allow scheduling on the same node
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/component
                operator: In
                values:
                  - controller
          topologyKey: "kubernetes.io/hostname"
```

Review the file and customize according to your needs - all configuration for nginx can be viewed on the ingress-nginx project [here](https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/values.yaml).

To install it, you can run the following commands:

> **Note**
> Newly created AWS EKS clusters may not have a load balancer controller installed. Follow the [instructions on AWS docs](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html) to create one first. 

```sh
helm repo add "ingress-nginx" "https://kubernetes.github.io/ingress-nginx"
kubectl create namespace nginx-ingress
helm install -n "nginx-ingress" "nginx-ingress" "ingress-nginx/ingress-nginx" -f nginx-values.yaml
```

Now run `kubectl -n nginx-ingress get svc` until it shows your new ingress IP:

```
NAME                                               TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)                      AGE
nginx-ingress-ingress-nginx-controller             LoadBalancer   10.0.208.205   xx.xx.xx.xxx   80:32438/TCP,443:30185/TCP   55s
nginx-ingress-ingress-nginx-controller-admission   ClusterIP      10.0.51.33     <none>         443/TCP                      55s
nginx-ingress-ingress-nginx-controller-metrics     ClusterIP      10.0.187.54    <none>         10254/TCP                    55s
```

At this point, it's recommended to decide on a domain to use for the Safe Surfer deployment. It can be a subdomain of your own domain, or whatever you wish. Then, create a wildcard DNS entry for any subdomains of that domain that points to your new external IP.

For example, if your domain was `ss.example.com` and your external IP was `0.0.0.0`, you'd create a DNS entry for `*.ss.example.com` pointing to `0.0.0.0`. Doing it this way is optional, but does save you some time. You can also have completely different domains for each Safe Surfer deployment.

## Enabling TLS
Various parts of the Safe Surfer deployment may require you to enable TLS. There are a few different ways to do this:
- If [cert manager](https://cert-manager.io/) is installed in the cluster, you can use the HTTP01 challenge mechanism to automatically generate, renew, and use a certificate from letsencrypt.
- Supply any custom cert/key pair.
- Supply the name of a secret containing the `tls.crt` and `tls.key` files. You can use this to set up a letsencrypt cert using [DNS01 validation](https://cert-manager.io/docs/configuration/acme/dns01/) with cert-manager.

### Installing cert-manager
The full instructions are [here](https://cert-manager.io/docs/installation/), but in most cases all you need is `kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml`.

This command will install cert manager to the `cert-manager` namespace. Run `kubectl -n cert-manager get pods` until you see a result like the following:

```
NAME                                      READY   STATUS    RESTARTS   AGE
cert-manager-99bb69456-jbjbc              1/1     Running   0          15s
cert-manager-cainjector-ffb4747bb-6fpbw   1/1     Running   0          16s
cert-manager-webhook-545bd5d7d8-7sd86     1/1     Running   0          14s
```

This means cert-manager is ready to start generating certificates.

### HTTP01 method
Enabling a certificate using HTTP01 validation is simple. Just add the following to the particular ingress definition:
```yaml
tls:
  http01: true
```

It is also recommended to add an email for letsencrypt to contact using the following top-level configuration in the chart:

```yaml
certmanager:
  letsencrypt:
    email: user@example.com
```

`HTTP01` validation is not available for `dns.doh`, `dns.dot`, or `protocolchecker`. In the case of `doh`/`dot`, this is because they do not use an ingress. For the `protocolchecker`, it's because it must obtain certs for domains that don't exist on the public internet (out of necessity). You'll need to use one of the other methods for these deployments.

`HTTP01` validation can also fail to work, or require more configuration, in non-standard environments with more restrictive permissions. This is because cert-manager might not have the permissions to create the pod required to solve the `HTTP01` challenge.

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
Supply the name of the secret to use for any deployment like this:

```yaml
tls:
  http01: false
  secretName: my-tls-secret
```

Note that the namespace of the deployment must match the namespace of the secret you wish to use.

### Using the DNS01 challenge type
[DNS01 validation](https://cert-manager.io/docs/configuration/acme/dns01/) with cert-manager has many advantages over HTTP01 validation:
- Does not require creating a pod, so works even when permissions are restrictive
- Does not require the domain to exist before the certificate can be created
- Does not require an ingress to exist for the domain of the certificate

However, it is also more difficult to configure, and the configuration is dependant on your authoritative DNS server. You can set up DNS01 validation by using the `secretName` method above and configuring cert-manager to create the secret with a matching name. You can also use the `customManifests` field of the chart values to keep all your resources in one place. Here is an example for if you were using cloudflare as the DNS server for the domain you're hosting Safe Surfer on:

```yaml
customManifests:
- apiVersion: v1
  kind: Secret
  metadata:
    name: cloudflare-api-token-secret
    # Ensure namespace matches that of the release's namespace
    # namespace:
  type: Opaque
  stringData:
    api-token: <API Token>
- apiVersion: cert-manager.io/v1
  kind: Issuer
  metadata:
    name: example-issuer
    # Ensure namespace matches that of the release's namespace
    # namespace:
  spec:
    acme:
      server: https://acme-v02.api.letsencrypt.org/directory
      preferredChain: 'ISRG Root X1'
      email: user@example.com
      privateKeySecretRef:
        name: my-tls-secret
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
    # Ensure namespace matches that of the release's namespace
    # namespace:
  spec:
    secretName: my-tls-secret
    issuerRef:
      name: example-issuer
      kind: Issuer
      group: cert-manager.io
    dnsNames:
    - '*.ss.example.com'
```

This will create a secret named `my-tls-secret` which you can then reference in the `secretName` field of any `tls` object, like above. If any domains other than the wildcard are required, you can add them to the `dnsNames` list.

For the full list of supported authoritative DNS providers supported by cert manager and how to configure them, check [cert-manager docs](https://cert-manager.io/docs/configuration/acme/dns01/).
