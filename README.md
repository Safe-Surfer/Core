# Safe Surfer Core
[Helm](https://helm.sh) Chart for Safe Surfer Core, our DNS filtering offering for ISPs and MSPs. Features include:
- Per-user and per-router client device DNS filtering. 
- Browsing history (DNS logging).
- Install DNS servers on VMs, bare metal, or Kubernetes.
- Integration with [Chargebee](https://chargebee.com) or any other billing provider.
- Syncing from Safe Surfer's central domain database.
- User management.
- DNS-over-HTTPS, DNS-over-TLS, and DNScrypt.
- Integration with [Alphasoc](https://alphasoc.com) for enterprise-grade DNS security analytics & alerts.
- Auto-categorization of newly discovered website domains (including CSAM detection).
- Built-in Grafana monitoring.

## Why?
Safe Surfer lets you protect families and vulnerable internet users from adult content, scams, addiction, or any other aspect of internet usage they're struggling with. We've helped hundreds of thousands of users already, including shipping our physical [lifeguard routers](https://shop.safesurfer.io/collections/resources/products/internet-lifeguard) but accessing internet filtering through their ISP directly will be the easiest route for many users.

Billing APIs allow you to monetise your new DNS filtering offering if you wish, or the features Safe Surfer provides can be a powerful form of differentiation.

Safe Surfer DNS is based on [PowerDNS](https://www.powerdns.com/), meaning you get all the assurance of a well-known, stable DNS server while using our advanced filtering.

## Guide
Here's everything you can achieve using Safe Surfer Core:
- [Getting started: Basic DNS filtering](./guides/getting-started.md)
- [Block Page](./guides/block-page.md)
- [Per User and Device Filtering](./guides/per-user-and-device-filtering.md)
- [Checking Protection](./guides/checking-protection.md)
- [Billing and Quotas](./guides/billing-and-quotas.md)
- [DOH and DOT](./guides/doh-and-dot.md)
- [Monitoring & Alerting](./guides/monitoring-and-alerting.md)
- [Auto Categorization](./guides/auto-categorization.md)
- [AlphaSOC Integration](./guides/alphasoc.md)
- [Building a Dashboard](./guides/building-a-dashboard.md)
- [Custom Router Integration](./guides/custom-router-integration.md)
- [Domain Mirroring](./guides/domain-mirroring.md)
- [Considerations for Production](./guides/prod-considerations.md)

Don't want to do it yourself? No problem. Contact us at [info@safesurfer.io](mailto:info@safesurfer.io) to set up a demo and/or deployment.

## Version support
- Kubernetes 1.20+
- For linux server installations, support for systemd + docker.

## Bugs, Feature Requests, and PRs
Please use Github issues. PRs welcomed but only the Helm chart itself is open source.

To contribute to our open source projects, see our [gitlab account](https://gitlab.com/safesurfer).

## Licensing
Contact us at [info@safesurfer.io](mailto:info@safesurfer.io) for a license key. Pricing is free for a demo, or POA for enterprise usage.

## Release Schedule
New releases are made bi-annually. See [changelog](./CHANGELOG.md) for the release history.

## Other resources
- [API docs](https://safesurfer.gitlab.io/api-docs/)
- [Admin App API docs](https://safesurfer.gitlab.io/admin-app-api-docs/)
- [Safe Surfer for ISPs page](https://safesurfer.io/for-isp/)
- See the full [values.yaml](./charts/safesurfer/values.yaml) for all possible configuration options.
