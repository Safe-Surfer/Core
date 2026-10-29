# Changelog

## 12.0.0 — 20 October 2026

This release covers everything since 11.0.0 (March 2025). It is a major version: several values moved or stopped being read.

### Breaking changes

- On Kubernetes, DNS-over-HTTPS and DNS-over-TLS no longer have their own Deployments or Services. `dns.doh.deployment`, `dns.doh.sidecar`, `dns.doh.replicas`, `dns.doh.deploymentStrategy`, `dns.doh.horizonalPodAutoscaler`, `dns.doh.affinity`, `dns.doh.podDisruptionBudget`, `dns.doh.service`, and `dns.doh.ipv6Service` are not read. The same fields under `dns.dot` are not read. With `dns.doh.enabled` or `dns.dot.enabled`, those containers run in the `dns.dns` pod and are published on `dns.dns.service.tcp` and `dns.dns.ipv6Service.tcp`: DoH on TCP 443, DoT on TCP 853. `dns.dns.service.tcp` and `dns.dns.service.udp` are still two Services. `dns.dns.hostNetwork` still binds the container ports on the node.
- `ss-config` still installs DoH and DoT as their own host services, `ss-doh.service` and `ss-dot.service`, when `dns.doh.enabled` or `dns.dot.enabled` is set. DoQ is `ss-doq.service` on the same path.
- Plain DNS is answered by a `dns-proxy` container (`dns.dns.plaindns`). The PowerDNS Recursor listens on `dns.dns.recursorPort` and only receives queries from the proxies in the same pod. `dns.dns.blockFirefoxDOH` has been removed. In 11.0.0 it defaulted to on, so Firefox's own DoH endpoint is no longer blocked by that switch.
- The DNS feed Deployment moved from `dns.lmdbFeed` to `feeds.dns`. No template reads `dns.lmdbFeed`. `feeds.dns` adds `lmdb`, `streamDomains`, `initLimit`, and `listenerTimeout`.
- `dns.newDomainNotifier` has been removed.
- In-cluster auto-categorization has been removed. `categorizer.autoCat`, `categorizer.adminApp.crawlerStorage`, and `categorizer.adminApp.newDomainNotifierUser` are gone, along with the classifier, crawler worker, and new-domain queue pods. The auto-categorization guide has been removed. The admin app exposes classifier-outpost APIs for an external classifier. That process is not deployed by this chart.
- The API checks these quota names. Helm merges `api.quotas`, so an old key left in your values is still passed through as its own quota. The API does not read it. Daily and weekly reset applies to names containing `per_day` or `per_week`.
  - `alerts_dismissed` is now `alerts_dismissed_per_day`
  - `cast_events` is now `cast_events_per_day`
  - `evasion_attempts` is now `evasion_attempts_per_day`
  - `location_history` is now `location_history_per_day`
  - `logged_notifications` is now `logged_notifications_per_day`
  - `nudity_detections` is now `nudity_detections_per_week`
  - `screencasts` is now `screencasts_per_day`
  - `vpn_attempts` is now `vpn_attempts_per_day`
- `api.rateLimiting` has been removed, and so has `monitoring.ingress.rateLimiting`. `categorizer.adminApp.rateLimiting.publicGetDomain` is unchanged.
- `whitelistSourceRange` is no longer read on the API, frontend, monitoring, admin app, health check, ClickHouse daemon, ipsetd, or feed ingresses. Allow source addresses with a Traefik `ipAllowList` middleware and `traefik.ingress.kubernetes.io/router.middlewares`. Feed LoadBalancer source ranges stay on `loadBalancerSourceRanges`.
- `api.sendgrid.senderAddress` and `api.sendgrid.senderName` are no longer injected into the API or mailbot. The sender is read from the `email-sender-name` and `email-sender-address` meta tags in the rendered email. Email theming stays under `api.emails.theme`.
- `api.dailyCleanup.timeouts` has been removed. Use `api.dailyCleanup.maxConcurrency`, `quotaLogMaxBatchDuration`, and `quotaLogMaxBatchSize`.
- The daily cleanup job no longer syncs Chargebee subscriptions.
- The DNS image build installs PowerDNS Recursor 5.4.5 or newer. 11.0.0 allowed 5.3.5 or newer. 5.4.5 includes the fixes in [PowerDNS Security Advisory 2026-08](https://doc.powerdns.com/recursor/security-advisories/powerdns-advisory-2026-08.html) and [2026-10](https://doc.powerdns.com/recursor/security-advisories/powerdns-advisory-2026-10.html).

### Migration guide

- For a Kubernetes install that set `dns.doh.deployment` or `dns.dot.deployment`, move replica, autoscaling, affinity, disruption-budget, and Service settings onto `dns.dns`. Delete `dns.doh.sidecar`, `dns.dot.sidecar`, and the removed fields listed above. DoH and DoT then use the DNS pod and its TCP Service. An `ss-config` install keeps `ss-doh.service` and `ss-dot.service`. Nothing moves there.
- Copy `dns.lmdbFeed` to `feeds.dns` and delete `dns.lmdbFeed`. Set `lmdb`, `streamDomains`, `initLimit`, and `listenerTimeout` if you do not want the chart defaults.
- If you deployed `dns.newDomainNotifier` or `categorizer.autoCat`, remove those values. Those pods will not come back on upgrade.
- Rename overridden quota keys to the names above. Leave the old key out, or it remains in the API config under the old name and is not enforced.
- Move any `whitelistSourceRange` value onto a Traefik `ipAllowList` middleware, and reference it from the ingress `annotations`. Move `api.rateLimiting` and `monitoring.ingress.rateLimiting` to a Traefik rate-limit middleware if you still want that limit.
- Move the SendGrid sender out of `api.sendgrid` and into the email HTML meta tags. Delete `api.dailyCleanup.timeouts` if you set it.
- Review `api.strings` for account-link invitation copy and the newer Apple profile strings before you upgrade a deployment that sends those emails or profiles.
- Run `helm repo update safesurfer` after this version is published, then upgrade.

### Non-breaking changes

#### DNS

- DNS-over-QUIC. Set `dns.doq.enabled`. On Kubernetes it is a `dns-proxy` container in the DNS pod, published as UDP 853 on `dns.dns.service.udp`. DoT stays on TCP 853. `protocolchecker.domains.doq` is the protocol-check name. 0-RTT is disabled. The default image is `dns-proxy:2.0.0`. `ss-config` runs it as `ss-doq.service`.
- `dns.doh.corsAllowedOrigins` sets CORS for `/dns-query` and `/server-info`. The default is `*`.
- `dns.clusterId` is returned by the DoH `/server-info` endpoint. An empty value becomes the Helm release name.
- `dns.dns.recursorPort` and `dns.dns.recursorExtraConfig` configure the recursor behind the filtering proxies.
- The DNS stack images referenced by the chart were rebuilt for amd64 and arm64.
- The DNS pod's Postgres LMDB init container and manager now receive `APP_LISTENER_TIMEOUT`, `APP_STREAM_DOMAINS`, and the full-rebuild intervals. Those come from `dns.dns.sidecarContainers.lmdbManager.backend.postgres` (`listenerTimeout` defaults to `30m`, `streamDomains` to `true`). Without them, `dns-feed` exits on startup. The standalone feed Deployments already set the same variables. `ss-config` 3.0.0 sets the same two variables on `ss-init-lmdb` and `ss-dns-feed`, and pins `dns-feed:1.0.1`. Shell scripts it writes are mode `0755`, and the cloud-init permissions field is `0755`.
- `dns.dns.deploymentStrategy.type: Recreate` no longer also renders `rollingUpdate`. Helm keeps the default `rollingUpdate` keys when you only override `type`, and Kubernetes rejects that combination. A one-node host-network DNS pod needs `Recreate`: the default rolling update tries to start a second pod on the same ports.
- An HTTP01 Issuer with no `ingress.class` is rendered as an empty `ingress: {}` object. cert-manager 1.17 rejects the previous empty value.
- The API receives `APP_TEXT_CLASSIFICATION_SUBMIT_JOBS_MAX` from `api.sessions.textClassificationSubmitJobsMax` (default `10`). Without it, `api:12.0.1` panics at startup even when text classification is not configured.
- Feed images are `dns-feed:1.0.1`, `auth-feed:1.0.1`, `subscription-feed:1.0.1`, and `smm-feed:1.0.1`. `1.0.1` treats `MAX(ID)` on an empty `wp_users` table as zero, so account segmentation can stay on for a new install. `1.0.0` exited during LMDB init in that case. The admin app image is `5.25.1`.

#### Frontend

- The reference dashboard image is `registry.gitlab.com/safesurfer/dashboard:3.0.0` (Vue 3). 11.0.0 used `dashboard:2.0.2`. Branding and deployment hosts are tokens and meta tags in that repo. Publish the `3.0.0` tag on `gitlab.com/safesurfer/dashboard` before installing the chart.

#### Feeds

- `feeds.dns` is the DNS feed Deployment that used to be `dns.lmdbFeed`.
- `feeds.blocking` distributes the blocking model.
- `feeds.subscription` distributes subscription and quota state.
- `feeds.auth` distributes the data needed to validate auth tokens. The tokens themselves are not in the feed.
- `feeds.smm` distributes text-classification job state.
- Each feed can be exposed with a ClusterIP, a LoadBalancer, or an Ingress. gRPC ingress depends on the controller. See the comments on `feeds` in `values.yaml`.

#### API

- Account linking. One account can invite another, up to `api.quotas.linked_accounts` (default 5). Invitation email is limited by `api.accounts.accountLinkInviteRateLimit` (default 10 per account per day). Looking up whether an address already has an account also counts against `createAccountRateLimit`.
- Sessions API, configured under `api.sessions`. This is the successor to screencasts and the notification log. Those older APIs are still served. Session quotas default to 0, which leaves the feature off. Stored images can be encrypted with `api.sessions.imageEncryptionKey` (32-byte AES-256 key, hex).
- Built-in text classification under `api.textClassification`. Point a text-classification provider at platform `internal`. Requires Redis. The worker and the llama.cpp server run as two containers in one pod. `guidedJSON` constrains the model output. New quotas: `text_classifications_per_week` and `text_classifications_per_week_2`.
- App usage uploads are acknowledged only after the batch commits to ClickHouse. Tune this with `api.appUsage`.
- Custom domain rules accept an include-subdomains flag on hostnames, shell-style globs, and regular expressions prefixed with `#re`. `dns-proxy:2.0.0` evaluates those patterns. `dns-feed:1.0.0` writes the pattern index.
- A new router client whose reported name matches an existing client is merged into that client. This is what covers a device that rotates its MAC address and keeps its DHCP name. New-device alerts are skipped for a merged client, and for a client that already belongs to a group.
- Alert queries can return the devices they apply to. No-activity alerts group adjacent quiet periods, including across devices, and record whether the quiet source was DNS or the browser extension.
- Sign-in reports `emailOtpRequired` when an email code is required even though the account has a password. `api.accounts.emailOtpDailyRateLimit` caps OTP email (default 10 per account per day).
- A category can be marked always-allowed in its metadata.
- Apple configuration profiles can target macOS, force the system proxy in managed browsers, and include Brave Origin.
- `api.rolesConfig` adds `macos` and `crx` (browser extension) roles.
- Renewal estimates are skipped for App Store and Play Store subscriptions. Chargebee returns `resource_not_found` for those subscription IDs, and that error used to fail the whole subscription lookup.
- Google Play API calls no longer derive their HTTP timeout from a context that has no deadline. A missing deadline used to produce a zero timeout and fail the call, including cancellation. The client now uses a 30 second timeout and refreshes the cached token 30 seconds before it expires.

#### Monitoring

- `monitoring.crewmateMetrics` collects crewmate job metrics for the built-in Grafana dashboards.

#### Admin app

- Classifier-outpost endpoints for unknown sites, uncategorized lists, and category suggestions. The outpost process itself is a separate image and is not deployed by this chart.
- Reserved TLDs such as `.arpa` can be allowed when adding a domain.
- List analytics can be filtered to uncategorized domains.

## 11.0.0

### Breaking changes
- `dns.doh` and `dns.dot` now support serving multiple certificates.
- The LMDB manager container now supports the new `lmdbFeed` backend as well as connecting to postgres directly. Using `lmdbFeed` instead of a direct connection benefits security, performance, and availability. 
- Each route ID under `api.routesConfig` now accepts a `maxRpm` parameter which decides the amount of requests per minute each pod may handle. This is mostly useful for websocket endpoints, which may be spammed if there is an interruption in network connectivity. These endpoints are set to 600 by default.
- Support any number of Apple `.mobileconfig` configurations, and support settings that require a supervised device.
- User comms consent is now an integration with sendgrid instead of storing the consent value in the deployment's database.
- The `app_rules_per_device` quota has been introduced. Previously the amount of app rules that could be created was the same as the amount of apps allowed per device (`apps_per_device`), but now app rules can be created in advance for apps that aren't installed yet.
- `GET /user/auth` has been removed from the API.
- `POST /user/auth` has been removed from the API.
- `POST /user/device/auth` has been removed from the API.
- `GET /user/subscription/chargebee/redirect/payment-methods` has been removed from the API.
- `GET /user/subscription/addons/extradevices` has been removed from the API.
- `PUT /user/subscription/addons/extradevices` has been removed from the API.
- `GET /user/subscription/name` has been removed from the API.
- `POST /user/subscription` has been removed from the API.
- `DELETE /user/subscription` has been removed from the API.
- `POST /user/subscription/reactivate` has been removed from the API.
- `POST /user/ip` has been removed from the API.
- `GET /user/ip` has been removed from the API.
- `POST /user` has been removed from the API.
- `GET /user/is-setup` has been removed from the API.
- `GET /categories/names` has been removed from the API.
- All `/usage` API endpoints have been removed.
- Add the concept of "reserved" metadata keys to the API. It is no longer valid to create a metadata key starting with `_reserved`.

### Migration guide
- If you are using DOH or DOT, `dns.doh.tls` and `dns.dot.tls` now expect an array. Each array element has the same format as the previously expected object.
- If you want to use LMDB feed instead of connecting the DNS to the database directly, configure the new `dns.lmdbFeed` deployment.
- If you don't want to use LMDB feed, you will have to update your values file. Any values previously under `dns.dns.sidecarContainers.lmdbManager` other than `resources`, `extraEnv`, `securityContext`, `image`, and `logLevel` are now located under `dns.dns.sidecarContainers.lmdbManager.backend.postgres`. Similarly; values under `dns.dns.initContainers.initLmdb` other than `resources`, `extraEnv`, `image`, `logLevel`, or `mapSize` must be moved to `dns.dns.initContainers.initLmdb.backend.postgres`.
- Depending on your usage, the default value of 600 RPM for API websocket endpoints may be too low. For example, if the timeout for the endpoints is 10 minutes, the average connection duration may be around 5 minutes. If you're running two API instances with 10,000 clients, you'd expect a value around 1000 instead (`1/5*10000*2`). This can be adjusted under `api.routesConfig`.
- If you're using the comms consent API, you'll need to pick the sendgrid unsubscribe group that the API will sync to. Then, using the admin app, export users with a negative or unknown comms consent status and add them to the unsubcribe group. Then, place the ID of the unsubscribe group as `api.sendgrid.commsConsentUnsubscribeGroup`.
- If you're using `api.devices.appleMobileConfig`, it's best to re-examine the desired settings and add them as named profiles in the new configuration. Then, update the frontend to request the new settings.
- Pull the dashboard updates that migrate to the new APIs. Then, build a new version and add to `values.yaml`.
- If you've enabled app blocking by setting the quota `app_rules_per_device` to something greater than 0, also set `app_rules_per_device` to at least that amount. 
- Review the API strings `otp_email_subject`, `otp_email_title`, `apple_mobileconfig_display_name`, `apple_mobileconfig_description`, `apple_mobileconfig_doh_display_name`, `apple_mobileconfig_doh_description`, `apple_mobileconfig_removal_password_description`, `apple_mobileconfig_restrictions_description`, and `apple_mobileconfig_filename`. They are either new or contain a placeholder.
- Deploy the new version. 
- If you've enabled it, `lmdbFeed` may take a little while to initialize depending on the size of your database. The new DNS deployment rollout won't succeed until it has initialized.

### Non-breaking changes

#### DNS
- When operating DOH or DOT in sidecar mode, the health check container now automatically creates health check targets named `doh` and `dot` to check the status of these containers.
- The `dns.doh.host` and `dns.dot.host` fields now supported comma-seperated values to support serving multiple hosts. Only the first value is used by frontend automatically.

#### API
- The API will now gracefully terminate websocket connections when a pod is terminated. You can use the `api.websocketShutdownRpm` parameter to control how quickly this occurs. You can use `api.terminationGracePeriodSeconds` to determine how long to give this process before forcefully terminating the pod. This prevents the API being spammed during deployment rollouts.
- Apple `.mobileconfig` files with custom settings for browsers set will now have an extension blocklist automatically populated using the app classifications database from the admin app. There are new app platforms for chromium extensions, edge extensions, and firefox extensions. Edge receives both chromium and edge extensions because it supports both.
- The per-IP rate limit for creating accounts is now configurable using `api.accounts.createAccountRateLimit.max`.
- The `/v2/blocking` APIs are the replacement for `/v2/categories` and `/v2/blockinternet`, which are now deprecated and will be removed in the next release.
- Add `/v2/devices` APIs to replace most under `/devices`, which are now deprecated and will be removed in the next release.
- Improve the speed of getting the last activity timestamp of router client devices.
- As part of the blocking APIs, users can group devices by members of their family or business. They can then manage blocking settings and history on a per-person basis instead of per-device.
- It is now possible to perform an in-term change of the user's plan. This occurs without putting the subscription into a "future" state.

#### Protocol checker
- `protocolchecker.domains.id` can be used to create a unique domain that will only resolve when the user is connected to a particular DNS instance. This can be useful to tell which deployment they are connected to.
- `protocolchecker.domains.tokenMatch` can be used to create a domain that will only resolve when the subdomain matches the DNS token being used by the user. This can be useful to tell whether the user is connected as a particular device without having access to the underlying network configuration.

## 10.0.0

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
