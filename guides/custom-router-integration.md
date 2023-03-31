# Custom Router integration
You can get per household/business/CPE filtering and logging just by linking an IP and giving out your Safe Surfer DNS IP over DHCP (or equivalent). But, Safe Surfer's integration for [openWRT](https://openwrt.org/) can deliver an even better parental control experience:
- Per-client device DNS filtering and logging.
- Enforcement of screentime rules at the IP level. This works through an advanced DNS-aware firewall, meaning that users can see internet access stop working instantly for a single app, while other apps remain unaffected. IPs are automatically discovered and categorized on a local, or optionally deployment-wide level. Screentime rules that block internet entirely work appropriately, while allowing any whitelisted domains to work properly.
- IP blocking.
- VPN detection.
- Firmware updates.

We currently maintain internal builds for [gl.inet](https://www.gl-inet.com/) devices for our [lifeguard](https://shop.safesurfer.io/collections/resources/products/internet-lifeguard) router, but the integration could be configured for any openWRT device. Contact us at [info@safesurfer.io](mailto:info@safesurfer.io) to inquire about a specific device. Devices can be configured *as* the CPE, or as an extra device that plugs in to the main CPE. Devices can connect to plain DNS or to DOH/DOT.

## Per-client filtering
See [per user and device filtering](./per-user-and-device-filtering.md).

## IP-level screentime/blocking
The IP-level features of the integration can be configured two different ways:
- Blocking only. In this mode, the router will only maintain enough IP information to block access to the internet entirely while allowing access to whitelisted domains. Per-site rules will still work, but only through DNS, which means updates to rules aren't always perceived as instant. This mode is recommended for devices with less than 256MB of RAM.
- Full. In this mode, the router gathers and categorizes IPs on a local and/or deployment wide level and blocks/unblocks them appropriately. Users will see internet access for particular apps stop immediately when access is revoked due to a screentime rule or rule change. Conflicts may occur when one IP hosts different domains, and in this case the router will cease blocking those IPs. This enhances the user experience with screentime, but does use a significant amount of RAM, so is only recommended for devices with at least 256MB of RAM.

### Deployment-wide IP categorization
Deployment-wide IP categorization lets you block IP addresses across every device running the router integration and connected to your deployment. There are three ways of doing this:
- Static. Add IP ranges manually using the `IPs` page in the admin app.
- Dynamic. Enable `dns.ipsetd` in your deployment's `values.yaml` to anonymously gather IP address categories according to the IPs that have resolved for domains on your DNS.
- Upstream. Enable `categorizer.ipMirroring` to set up IPs according to our central database. Note that when using this, you cannot use the `Static` method. Requires an API key to our categorizer. Maps according to your domain mirroring configuration.

## VPN detection
If enabled, the router integration can detect VPN usage based on the data usage and DNS lookups of each connected device. It can then upload this to the VPN API, which will then show in alerts.

## Firmware updates
Coordinates sysupgrade according to firmware you upload. Must be triggered by the user.
