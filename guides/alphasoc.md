# AlphaSOC
[AlphaSOC](https://alphasoc.com) analyzes DNS requests to find security threats. With an API key, you can self-host AlphaSOC within the Safe Surfer Core chart to provide security alerts through the Safe Surfer API. Before proceeding with this guide, you should complete the [per user and device filtering guide](./per-user-and-device-filtering.md).

You should also [contact AlphaSOC](https://www.alphasoc.com/contact/) for an API key.

To enable alphasoc, overwrite the following keys within your `values.yaml`:

```yaml
alphasoc:
  enabled: true
  apiKey: my-api-key
  internal:
    # Tone down resources for testing
    resources:
      requests:
        memory: "128Mi"
        cpu: "50m"
      limits:
        memory: "256Mi"
        cpu: "150m"
dns:
  clickhoused:
    internal:
      backend:
        alphasoc:
          enabled: true
```

Then upgrade the release. You should then see something like the following after running `kubectl get pods`:

```
NAME                                           READY   STATUS      RESTARTS         AGE
safesurfer-alphasoc-0                          1/1     Running     0                37s
```

However, no data will be going in to AlphaSOC yet because the `security_alert_endpoints_per_hour` quota is `0` by default. This is because AlphaSOC's [pricing](https://docs.alphasoc.com/licensing/#pricing-tiers) is per-endpoint, so you must consider carefully how many different endpoints to allow. An endpoint in Safe Surfer terms is each device, and router client devices are counted as separate devices in this case. See the [quota guide](./billing-and-quotas.md) for the ways you could configure this. As an example, we will just allow 10 endpoints per hour for all users with the following yaml:

```yaml
api:
  quotas:
    security_alert_endpoints_per_hour:
      maxValue: 10
```

After apply the above, we can send some usage data to the DNS and watch `clickhoused` send it off the AlphaSOC. E.g:

```sh
dig +short @$DNS_IP "+ednsopt=65001:000000000000" "+ednsopt=65002:$(echo $DNS_TOKEN | tr -d '-')" twitter.com
```

Now run `kubectl logs safesurfer-clickhoused-57778b86d6-lq4mt`, substituting the name of your own `clickhoused` pod. You should see a log like the following:

```
time="2023-03-27T21:15:07Z" level=info msg="sent logs successfully" backend=alphasoc-ae fields.time=107.453688ms numLogs=3 timeout=8s
```

The best way to test AlphaSOC from here is to throw some real traffic at it. Since their site database and heuristics change regularly, it's difficult to give a concrete example that will trigger an alert. A good amount of real traffic will usually generate at least a few low-priority alerts.

It's also worth noting that processing of security alerts is asynchronous. Events are processed some time after being received by AlphaSOC, and then synced to the Safe Surfer database by the sync cronjob, which by default runs every hour.

If you would like to run the sync job manually, you can run the following commands:

```sh
kubectl delete job alphasync-manual
kubectl create job alphasync-manual --from=cj/safesurfer-alphasoc-sync
```

Substitute `safesurfer-alphasoc-sync` for the name of your cronjob. It's ok if the first command reports the job doesn't exist. You can run the sync job as many times as you like without generating duplicate alerts, *but not concurrently*. The cronjob will never run concurrently, but manual runs may so some care is needed.

If successful, the job will show output like the following:

```
time="2023-03-27T21:28:37Z" level=info msg="creating new db connection"
time="2023-03-27T21:28:37Z" level=info msg="all alerts have been synced" stats="{\"Success\":0,\"SkippedDeviceOrAccountDeleted\":0,\"SkippedBadDomain\":0,\"SkippedUnknownEventType\":0,\"SkippedDeleted\":0,\"SkippedIgnore\":0}"
```

After syncing, alerts are retreived from the Alerts or Security Alerts APIs. This means that they are sent as part of alert emails too. Security Alerts are kept for 90 days, like browsing history.
