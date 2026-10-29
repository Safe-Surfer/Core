# Known Issues
Generally any issues will be patched, but there are a few out of our control, often in the interaction between the chart and various dependencies.

## `Referenced "Issuer" not found` when using HTTP01 certs
The chart creates the cert-manager issuer and the `Certificate` in the same Helm apply. cert-manager can process the `Certificate` before the issuer exists. The event is `IssuerNotFound`, and the message is `Referenced "Issuer" not found` or `Referenced "ClusterIssuer" not found`. A normal release uses an `Issuer`. A release with `testFlags.legacyNames` uses a `ClusterIssuer`, so the message names that kind instead.

This only happens for HTTP01. A `tls.secretName` does not create an issuer.

cert-manager often retries and recovers on its own. If the `Certificate` stays unready, delete that `Certificate` and upgrade the release again. The issuer is already there, so the new `Certificate` can use it.
