# Changelog

## Next

### Breaking changes
- Many requests on the API that require user IP address information will now fail and return 500 if `api.realIPHeader` is not configured correctly. For more details, see the API section below.
- The version 1 alert API endpoints have been removed. These have not been used for a long while and have been replaced by v2.
- Rename `api.strings.usage_unknown_category_name` to `api.strings.unknown_category_name` to reflect the fact that the string constant may now also be returned in alerts for recently installed apps.
- Alerts for blocked requests to categories that aren't displayed may now be returned. Before, alerts were not returned for categories that were not displayed.
- `api.devices.appleMobileConfig.payloadContentIdentifier` and `api.devices.appleMobileConfig.payloadIdentifier` have been removed in favor of `api.devices.appleMobileConfig.identifiers.payload` and `api.devices.appleMobileConfig.identifiers.dnsSettings` respectively.
- The `healthChecks` deployment now uses a `dnsPolicy` of `Default` by default, where before it was using `ClusterFirst`. This is only a breaking change if you were health-checking anything inside the cluster using kubernetes DNS names, regular DNS should work as expected given DNS on the nodes working.
- Downloaded apple `.mobileconfig` files are now set to apply to the whole system, not just the current user.

### Migration guide
- If `api.enabled` is true, examine the logs of your API pods and ensure that the request logs show a valid source IP. If `api.realIPHeader` is not configured correctly, an IP from one of the [private ranges](https://en.wikipedia.org/wiki/Private_network) will be shown. If a private IP range is shown, configure `api.realIPHeader` to match a header set by your ingress. Requesting the root of the API will dump the headers that the API can see.
- If you are overriding `api.strings.usage_unknown_category_name` in your own values, change this to `api.strings.unknown_category_name`.
- Examine your category list to find categories with alerts enabled that are not displayed. Alerts for these categories may now be returned to customers. If you don't want this, you can turn alerts off for the category, or change the logging visibility to avoid logging any requests for the categories.
- If you are overriding `api.devices.appleMobileConfig.payloadContentIdentifier` or `api.devices.appleMobileConfig.payloadIdentifier` in your values, change these to `api.devices.appleMobileConfig.identifiers.payload` and `api.devices.appleMobileConfig.identifiers.dnsSettings` respectively.
- If you are using `healthChecks` to health-check DNS names inside the cluster, set `healthChecks.dnsPolicy` back to `ClusterFirst` in your values.
- Run `helm repo update safesurfer` to get the latest chart version.
- Finally, upgrade the chart deployment.

### Non-breaking changes

#### Chart
- Add the `api.extraQuotas` field to define arbitrary quotas. This was possible previously, but required replacing the entire `api.quotas` object.

#### DNS
- Add `dns.dot.service.isGCPNEG` to easily provision a Google Cloud Network Endpoint Group for DOT.

#### LMDB manager
- Fix a bug where live updates could hang if there was a database connection issue as the container starts.
- Add `dns.dns.sidecarContainers.lmdbManager.accountFullRebuildWindow` and `dns.dns.sidecarContainers.lmdbManager.domainFullRebuildWindow` to add some randomness around when full rebuilds occur. This helps to reduce database load.

#### API
- Add device metadata to associate arbitrary key/value data with devices. This feature is off by default, since you must define the valid keys in the `api.devices.metadata` object to enable it.
- Support various extra settings provisioned via apple `.mobileconfig` files. These extra settings are off by default, but force browsers to use the DNS provisioned as part of the profile, so provide a better user experience. This can be configured in `api.devices.appleMobileConfig.extraSettings` and `api.devices.appleMobileConfig.identifiers`. To return these for a given request for a mobileconfig file, you must opt in by setting the `enable-extra-settings` parameter.
- Fix a bug where the internal quota live-updates websocket could fail silently without returning an error.
- Fix a bug where the estimate for changing addon quantity would not include other addons currently on the user's subscription in the next invoice.
- Add third-party nudity detection providers. Currently this is only used for the screencast feature so is off by default.
- Add location tracking API (off by default).
- By default, change the `android` role to allow the app to set the app version, retreive its own metadata, and post its location.
- Add a minimum priority setting to alert emails. By default, the alert email settings for newly created accounts now has the daily email configured to high priority as a minimum.
- Add alerts for newly installed apps.
- Add a setting for app approval. When this is on for a device, newly added apps will be blocked by default until an explicit decision is made.
- Add an API in the new blocking endpoint group to toggle the above.
- Add an API in the new blocking endpoint group to get the app blocking settings.
- Add an API in the new blocking endpoint group to set the base category settings.
- Improve alerts performance.
- The following operations now require `api.realIPHeader` to be configured correctly to find the user's source IP, or they will fail and return 500: creating a user, signing in with a username/password, using remote authentication, adding a survey result, getting the user's source IP, setting the IPv6 address for a device, setting the IPv4 address for a device, and chargebee subscription operations that require the user's source IP. Source IP is required for estimating or creating a chargebee subscription, or getting a chargebee plan, when the full plan ID is not provided and the user's source IP is used to determine the real plan or plan price ID.
- Improve request logging.

#### Mailbot
- Increase default memory limit.

#### Health checks
- Add `dnsPolicy` and `dnsConfig` fields to `healthChecks`. Using `ClusterFirst` DNS can result in false positive health check failures if the cluster's DNS setup can't handle the amount of requests the health checks require. The new default value, `Default`, uses the DNS of the nodes, which removes the overhead of matching all DNS names with in-cluster DNS.

#### Admin App
- Fix a bug where requesting the [domain categories](https://safesurfer.gitlab.io/admin-app-api-docs/#tag/domains/operation/getPublicSearch) API from inside the cluster would crash the requested admin app pod when `categorizer.adminApp.realIPHeader` was set, unless the `realIPHeader` header was set manually on the request.
- Fix a bug in the situation where `categorizer.adminApp.authIpWhitelist` and `categorizer.adminApp.realIPHeader` were both set and requests were made to the admin app from inside the cluster. Previously, this would crash the requested admin app pod unless the `realIPHeader` header was set manually on the request to an allowed value.
- Improve request logging.

#### Reference dashboard
- Set a user's timezone when their account is created or when they sign in. This avoids the dates being incorrect on alert emails.
- When changing addon quantity with proration enabled, name prorated charges "upfront charges" instead of prorated charges.

## 9.0.1

### Non-breaking changes

#### DNS
- Integrate upstream PowerDNS patches to fix [CVE-2023-50387/CVE-2023-50868](https://doc.powerdns.com/recursor/security-advisories/powerdns-advisory-2024-01.html).

## 9.0.0

### Breaking changes
- `newDomainNotifierUser.user` may no longer be named `Auto-Categorizer`, since this is also the default username for `addFromDNS`, which could result in `addFromDNS` not working.
- Remove most of the v1 `/categories` and `/sites` endpoints from the API, as they have not been used in a long time. Only `/categories/names` is preserved, as it is still used in the default dashboard and lacks a suitable replacement at this stage.

### Migration guide
- If you have set `newDomainNotifierUser.user` to `Auto-Categorizer`, rename it something else. A suggested replacement is `New-Domain-Notifier`.

Other than this, no special migration steps are necessary, unless the v1 `/categories` or `/sites` API endpoints were being used in some way to change blocking settings. However, no available implementation for any platform was using these. 

### Non-breaking changes

#### DNS
- Improve performance and reduce LMDB size.
- Add `dns.dns.debugging.categoryDomain`, which can be queried to view the current action for a particular category for the requesting device.
- The debugging domains under `dns.dns.debugging` can now be set to the empty string to disable them individually.

#### API
- Add `GET /v2/blocking/this-device/categories/{id}/resolved` to get the resolved category model for a single category for the requesting device.
- Add `GET /v2/blocking/by-category/{id}/plans` to get the blocking plans for a category across the whole account.
- Add `api.blocking.maxPlanAheadDuration` in `values.yaml` to decide the maximum amount of time users can request to see in the future when requesting blocking plans.
- Email OTP codes are now case-insensitive. Previously they only contained capital letters and would not accept lowercase, now either are accepted.
- The request config for websocket endpoints now configures the maximum duration websockets may be connected. Previously, the maximum duration for websocket endpoints was ignored. To assist with this, default values have been added of `10m`.
- Fix a bug where app live updates would not be dispatched after the API instance is running for a certain amount of time.

#### Admin App
- Add APIs to change Email OTP settings for individual users.
- Fix domains with internationalized TLDs being called invalid.
- Fix internationalized domains with punycode containing dashes being called invalid.

#### Crawler
- Retry through network errors on the initial load of a page. The time taken doing this is limited to, and counts against, the max page wait for each page.

#### Monitoring
- Fix some Grafana dashboards for auto-categorization not working for some setups.

## 8.0.0

### Breaking changes
- The LMDB manager container has been completely rebuilt to remove some of the limitations of the old version. The new version syncs domains, accounts, and categories from one container, rather than separate containers for each resource type. The only configuration change this brings is to the resources, which are now set for the one container instead of the two previous containers. Specifically, `dns.dns.sidecarContainers.lmdbManager.resources.domains` and `dns.dns.sidecarContainers.lmdbManager.resources.accounts` have been removed in favor of just `dns.dns.sidecarContainers.lmdbManager.resources`. Separate resource settings for the lmdb init container have been added under `dns.dns.initContainers.initLmdb.resources`.
- You can now define multiple mirrors for a single category. As such, some APIs related to this have been changed/removed. See Migration Guide below for more details.
- `clickhoused` has been updated to support both the UDP and HTTP frontends at the same time. This makes it easier to support DNS servers hosted both within the same cluster and externally.
- Worst-case duration of getting alerts from the API has been greatly improved by removing `api.alerts.lookaheadMultiplier` in favor of `api.alerts.lookaheadMultiplierStart`, `api.alerts.lookaheadMultiplierEnd`, and `api.alerts.lookaheadMultiplierFactor`. In the old version, there would be occasional timeouts when getting alerts if a large amount of summarizible alerts were found. In the new version, the lookahead increases exponentially according to the parameters above. This reduces resource usage of getting alerts in most cases while reducing the amount of timeouts.
- Recent prometheus versions have changed the names of labels used to query for particular kubernetes metrics. To make the built-in dashboards work when prometheus is installed as instructed in the [monitoring stack](https://gitlab.com/safesurfer/monitoring-stack) repo, these labels have been modified.
- The ability to edit whether a category is a site from the admin app UI has been removed, since this field is no longer used.
- Categories with "Exclude from Usage Data" ticked will no longer show in DNS debug queries. Because of this, IP blocking can no longer be enabled in conjunction with "Exclude from Usage Data".

### Migration guide
- The `GET /categories/{id}/mirror` and `DELETE /categories/{id}/mirror` API endpoints have been removed from the admin app. If you're calling these externally, you'll need to switch to using the alternatives `GET /categories/mirrors` and `DELETE /categories/mirrors` instead.
- If you have customized the resources for LMDB manager using `dns.dns.sidecarContainers.lmdbManager.resources.domains` or `dns.dns.sidecarContainers.lmdbManager.resources.accounts`, you will need to remove and combine (add together) the customized resources and place them directly under `dns.dns.sidecarContainers.lmdbManager.resources` instead. For example, instead of:
```yaml
dns:
  dns:
    sidecarContainers:
      lmdbManager:
        resources:
          accounts:
            requests:
              memory: "1000Mi"
              cpu: "100m"
            limits:
              memory: "1000Mi"
              cpu: "750m"
          domains:
            requests:
              memory: "2000Mi"
              cpu: "200m"
            limits:
              memory: "2000Mi"
              cpu: "500m"
```
You will now need:
```yaml
dns:
  dns:
    sidecarContainers:
      lmdbManager:
        # Adding the previous resources together:
        resources:
          requests:
            memory: "3000Mi"
            cpu: "300m"
          limits:
            memory: "3000Mi"
            cpu: "1250m"
```
You will also need to update the custom resources for the init container. This is generally the same as the sidecar. For example:
```yaml
dns:
  dns:
    initContainers:
      initLmdb:
        # Same as the above is a good starting point
        resources:
          requests:
            memory: "3000Mi"
            cpu: "300m"
          limits:
            memory: "3000Mi"
            cpu: "1250m"
```
Note that since this is a different implementation, the resource usage characteristics will vary slightly - it's worth monitoring your new resource settings after deployment. The new version has more configuration options to achieve the desired performance characteristics, which you can see in the new values file.
- If you have enabled the http frontend for `clickhoused`, you will now need to enable it explicitly rather than just disabling the udp frontend since it now supports both. Instead of:
```yaml
dns:
  clickhoused:
    internal:
      frontend:
        udp:
          enabled: false
```
You will now need:
```yaml
dns:
  clickhoused:
    internal:
      frontend:
        udp:
          enabled: false
        http:
          enabled: true
```
- If `monitoring.enabled` is `true`, you may need to upgrade the grafana/loki/prometheus stack for the built-in grafana dashboards to work after upgrading the Safe Surfer chart. Here is an example (run within the [monitoring stack](https://gitlab.com/safesurfer/monitoring-stack) repo), but if you are using custom values, make sure to include them instead: 
```sh
git pull # Monitoring stack repo has been updated
helm repo update prometheus-community
helm repo update grafana
helm -n monitoring upgrade prometheus prometheus-community/prometheus -f prometheus/values.yaml
helm -n monitoring upgrade loki grafana/loki-stack -f values.yaml
helm -n monitoring upgrade grafana grafana/grafana -f values.yaml
```
- If you are using `api.alerts.lookaheadMultiplier` in your values, remove it. In most cases you will not need to edit its replacement values `api.alerts.lookaheadMultiplierStart`, `api.alerts.lookaheadMultiplierEnd`, and `api.alerts.lookaheadMultiplierFactor`, but you can optimize by observing latency for `GET /v2/alerts` and `POST /v2/alerts/with-filter` and increasing the multipliers if necessary.
- If both "Exclude from Usage Data" and "IP Blocking Enabled" are ticked for any of your categories, IP blocking will no longer function on those categories. Change your settings accordingly before upgrading.
- After performing the steps above, you can now deploy the new chart version.

### Non-breaking changes

#### New
- Add the `healthChecks` deployment, which is an optional but useful way to generate prometheus metrics for the health of the services you enable in the rest of the chart. The metrics can be viewed in the new grafana dashboard for `healthChecks`, or you can use prometheus alerting rules to create alerts for them.

#### Chart
- Fix some cron formats for periodic jobs not being accepted.
- Fix the `api.ingress.tls.secretName` field not working.
- Fix Horizontal Pod Autoscalers not working on newer k8s versions.
- Fix HTTP01 certs not working with the chart.
- Fix certs not working for the grafana ingress.
- Fix a class of bug (see [this helm issue](https://github.com/helm/helm/issues/1707)) where large integers provided as values would not be parsed correctly.
- Add the `blockpage.svcAnnotations` annotations to put arbitrary annotations on the block page service. The default makes the block page work on AWS EKS by default.
- Add default values for `dns.dns.debugging`.
- Add the `maxIdleConns` and `maxOpenConns` parameters to most deployments that connect to the database. The defaults are the go defaults used previously.
- Resource requests/limits can now be customized for `dns.dns.initContainers.iptablesProvisioner`, `dns.dns.initContainers.ip6tablesProvisioner`, and `dns.dns.initContainers.udpOverIpv6AddressRewrite`.

#### DNS
- The domains in the `levels` field of restrictions will now live-update rather than requiring a full rebuild.
- The `isGlobalWhitelist`, `logging`, and `excludeFromUsageData` fields of categories will now live-update rather than requiring a full rebuild.
- Support plain DNS over IPv6 and linking IPv6 addresses to devices. See `dns.dns.localAddress`, `dns.dns.initContainers.ip6tablesProvisioner`, and `dns.dns.initContainers.udpOverIpv6AddressRewrite`.
- Support outgoing queries over IPv6. See `dns.dns.queryLocalAddress`.
- Add configurable sysctl settings for the DNS. See `dns.dns.sysctls`.
- Reduce the default `dns.dns.logLevel` to `6`.
- Add the `.dns.dns.anonymousLogging.allowOptOut` setting, which controls whether user requests will be logged anonymously instead when they opt out of logging. The default is `true`, which does not change the current behavior of turning off logging completely when users turn it off.
- Add a per-category logging setting.
- Add the `healthCheck.ignoreCert` option to `dns.doh` and `dns.dot`, which can be useful when deploying behind a load balancer that handles SSL.

#### API
- Fix an issue where the health check would succeed even if connected to a postgres replica by error or misconfiguration.
- Fix an issue where the alerts API could return duplicate alerts if a query took a long time and new alerts were added during the query.
- Fix some missing spacing in the default string templates.
- Support IPv6 in all places that support an IP.
- Add an API for linking IPv6 addresses with devices.
- Add APIs for blocking and syncing the apps on Android devices.
- Add an API endpoint to get or enable a self-service token for the requesting device. This means that self-service tokens are now effectively on by default. They can be disabled per-device by calling the endpoint to delete the self-service token for the device. They can be disabled by default by disabling endpoint ID `223`. The router or app integrations can use this to automatically provide more accurate information about why a certain site or app is blocked.
- Fix a bug where the live updates websocket would fail to take into account timetables that were active on a generic basis, such as on all days, weekends, or weekdays. This increased the amount of time before such timetables took effect, but they still took effect because the DNS recognized such rules properly, which the router integration also keeps watch of.
- Fix creating Google Play subscriptions not working through the V2 subscriptions API.
- Fix a bug where the [PUT /v2/user/block-page](https://safesurfer.gitlab.io/api-docs/#tag/userv2/operation/putBlockPage) endpoint would return 400 if the `customDomain` was not a valid domain, even if the custom domain was not being used, e.g. `enabled` was `false`. This prevented the reference dashboard from setting this setting back to the default.
- Add endpoints to retreive all block internet timers rather than having to make a request for each possible day.
- Add the new default `windows` auth token role.
- Add `api.accounts.emailOtpRateLimit`, `api.accounts.passwordResetRateLimit`, and `api.accounts.twofactor.rateLimit` as separate limits to `api.accounts.signonRateLimit` with a stricter default config. Before they were shared and it was difficult to find a good compromise between them.
- Remove `api.accounts.signonRateLimit.startDuration` and `api.accounts.signonRateLimit.endDuration`, since they did not change the amount of requests that could potentially be spammed, but did make the user experience worse when enabled. The default value was to disable this system.
- Add support for locking two-factor authentication submissions after a certain amount of submissions using `api.accounts.twofactor.attempts`.

#### Admin app
- Domain names containing underscores will now be accepted.
- Fix an issue where the health check would succeed even if connected to a postgres replica by error or misconfiguration.
- Remove `.host` as a reserved TLD, since this is a real TLD. Adding `.host` domains previously resulted in an error.
- Support IPv6. For the admin app this only affects the logs and rate-limiting or allowlisting by source IP.
- Add API/UI for categorizing Android apps.
- Remove case-sensitivity when searching for users by their email using either the [individual](https://safesurfer.gitlab.io/admin-app-api-docs/#tag/users/operation/getUser) or [group](https://safesurfer.gitlab.io/admin-app-api-docs/#tag/users/operation/postUserSearchJob) endpoints.
- Hide the screentime-blocking categories when associating domains, IPs, or apps with categories. Selecting these categories would have had no effect.
- UI improvements.

#### Domain mirror sync
- Allow adding mirrors from multiple remotes.
- Allow syncing domains from one remote category into multiple local categories.
- Allow syncing domains from multiple remote categories into one local category.
- Allow incremental (fast) syncs from one remote to continue while full (slow) syncs from other remotes are running.
- Run every minute by default.

#### Ipsetd
- Log the amount of IPs filtered out.

#### Block page
- Add the `enabledForUsersByDefault`, which allows using nxdomain as a blocking response by default while allowing this to be changed by users individually still.

#### Monitoring
- Fix an issue where some dashboards wouldn't work when multiple chart releases provisioned dashboards for the same Grafana instance.

#### `ss-config` tool.
- The provided values file now acts as an override to the default values rather than *being* the full values file. This allows keeping the provided values file much more concise, and matches the behavior of the helm chart.
- Add support for `.dns.dnscrypt`.
- Fix `.dns.dns.sidecarContainers.healthCheck.customTargets` not working.
- Allow turning off cert sync for doh/dot (officially) by removing/commenting the `certSync` object from the values file.

#### Reference dashboard
- Various UI improvements to screentime on the reference dashboard, see [this commit](https://gitlab.com/safesurfer/dashboard/-/commit/a8170b1b8fe03cb3215e7175d2ac46e8d66b63ee) for more details.
- Fix a bug on the reference dashboard where device reauth wouldn't work if the user had 2fa enabled, were over the device limit, and the device had to be re-created due to being deleted. They would have to re-open the reauthentication page to make it work. Note that the device reauth page is only used by the mobile apps.
