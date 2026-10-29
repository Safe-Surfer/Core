# Checking protection
It's sometimes useful to be able to check whether users are connected to the Safe Surfer DNS or not. To provide this functionality, you can enable the `protocolchecker`. Add something like the following to your `values.yaml`:

```yaml
protocolchecker:
  enabled: true
  domains:
    base: check.ss.example.com # shared suffix
    active: active # active.check.ss.example.com
    plain: plain # plain.check.ss.example.com
    dnscrypt: dnscrypt # dnscrypt.check.ss.example.com
    doh: doh # doh.check.ss.example.com
    dot: dot # dot.check.ss.example.com
    doq: doq # doq.check.ss.example.com
    router: router # router.check.ss.example.com
    # Answers on every protocol. Use a different label per deployment
    # when you want to see which cluster a user is connected to.
    id: default # default.check.ss.example.com
    # <dns-token>.token.check.ss.example.com answers only for that token.
    tokenMatch: token
```

`base` is the shared suffix. Each other field is the label in front of it. If you leave `doq`, `id`, or `tokenMatch` out, the chart defaults (`doq`, `default`, and `token`) still apply.

Safe Surfer DNS CNAMEs these names to `active`, and only from the protocol that name belongs to:

- `plain` from plain DNS
- `doh`, `dot`, and `doq` from those listeners
- `dnscrypt` from the DNSCrypt listener
- `id` from every protocol
- `<token>.<tokenMatch>` only when the query is using that DNS token

The ingress serves `active`, `plain`, `dnscrypt`, `doh`, `dot`, `router`, and `*.<tokenMatch>`. `doq` and `id` are answered in DNS only. The dashboard requests plain DNS, DoT, DoH, and DNSCrypt.

Ensure you create a DNS entry for your equivalent of `active.check.ss.example.com` pointing to your ingress's IP address.

> **Note**
> It isn't possible to complete this guide when using KIND/minikube.

Obtaining a valid certificate for the protocol checker can be trickier than the other deployments, since the domains you define here don't exist on the public internet (apart from `active.check.ss.example.com`). So you will have to use one of the other methods as shown in [ingress and cert setup](./ingress-and-cert-setup.md). HTTP-01 validation is not supported. Place the TLS configuration inside `protocolchecker.tls`. The generated certificate covers `*.<base>` and `*.<tokenMatch>.<base>`.

If you are using a wildcard TLS setup, you may like to change the above to something like the following:

```yaml
protocolchecker:
  enabled: true
  domains:
    base: ss.example.com # Your domain here
    active: active-check # active-check.ss.example.com
    plain: plain-check # plain-check.ss.example.com
    dnscrypt: dnscrypt-check # dnscrypt-check.ss.example.com
    doh: doh-check # doh-check.ss.example.com
    dot: dot-check # dot-check.ss.example.com
    doq: doq-check # doq-check.ss.example.com
    router: router-check # router-check.ss.example.com
    id: default-check # default-check.ss.example.com
    tokenMatch: token-check # <dns-token>.token-check.ss.example.com
  tls:
    secretName: my-wildcard-tls
    # OR
    custom:
      cert:
      key:
```

This will allow the check domains to be covered under the same TLS certificate.

> **Warning**
> You must ensure that no domain other than `active` actually resolves on the public internet, otherwise your check will always be positive. If you created a wildcard DNS entry and are using the wildcard TLS setup, you should remove the wildcard DNS entry and point only valid subdomains to the ingress manually instead. The wildcard TLS will still work.

Once you have a valid certificate and the DNS entry has propagated, you should be able to query your `active` domain:

```sh
$ curl https://active.check.ss.example.com
```
```
Protocol Active
```

After connecting to your Safe Surfer DNS instance, the `plain` domain should resolve too:

```sh
$ curl https://plain.check.ss.example.com
```
```
Protocol Active
```

The same check works for `doh`, `dot`, and `dnscrypt` when the browser is using that protocol. `doq` is a DNS answer only, so `curl` does not apply to it.

The chart frontend copies `plain`, `doh`, `dot`, `dnscrypt`, and `router` into the dashboard from these values, including when the checker deployment itself is still disabled. On the device setup instructions, a **Check protection** button requests the plain, DoT, DoH, and DNSCrypt names. It becomes a blue **Protected** button when one of them returns `Protocol Active`. `router` is a separate request the dashboard uses to notice that the browser is on a router running the integration.

That button sits on the setup instructions, under the DNS server addresses.
