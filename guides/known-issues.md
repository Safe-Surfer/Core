# Known Issues
Generally any issues will be patched, but there are a few out of our control, often in the interaction between the chart and various dependencies.

## `Referenced "Issuer" not found` when using HTTP01 certs
This is a race condition within cert manager. Delete the certificate resource and then re-deploy the chart. Cert manager should then correctly recognize the certificate-issuer relationship.
