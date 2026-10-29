# Building a dashboard
The Safe Surfer deployment provides many useful APIs to users, and also a default [dashboard](https://gitlab.com/safesurfer/dashboard) implementation to utilize them. But you may wish to take a different approach, such as integrating the APIs into your own dashboard.

The choices are:
- Is Safe Surfer managing the user accounts (e.g. `api.accounts.managed` is `false`), or do you already have your own account management? (e.g. `api.accounts.managed` is `true`)
- Will the custom dashboard be frontend or backend rendered, or both?
- Will the custom dashboard be hosted within the same Kubernetes cluster as the Safe Surfer deployment?

We can visualize this with a table:

|        | Safe Surfer is account management | Other account management |
| ------ | ------ | ------ |
| Forked dashboard | [Scenario 1](./building-a-dashboard.md#scenario-1-safe-surfer-is-account-management-forked-dashboard) | [Scenario 2](./building-a-dashboard.md#scenario-2-other-account-management-forked-dashboard) |
| Own dashboard (backend rendering or frontend+backend) | [Scenario 3](./building-a-dashboard.md#scenario-3-safe-surfer-is-account-management-own-dashboard-backend-rendering-or-frontendbackend) | [Scenario 4](./building-a-dashboard.md#scenario-4-other-account-management-own-dashboard-backend-rendering) |
| Own dashboard (frontend rendering) | [Scenario 5](./building-a-dashboard.md#scenario-5-safe-surfer-is-account-management-own-dashboard-frontend-rendering) | [Scenario 6](./building-a-dashboard.md#scenario-6-other-account-management-own-dashboard-frontend-rendering) |

## Scenario 1 (Safe Surfer is account management, Forked dashboard)
This is the simplest scenario. All you have to do is customize the dashboard according to your needs, then build a version and provide the URL to the version to the `frontend.image` parameter, e.g:

```yaml
frontend:
  enabled: true
  image: registry.gitlab.com/organization/forked-dashboard:1.0.0 # 1.0.0 is the gitlab tag used to build the image
```

Or if you wish to host the forked frontend externally, you can set the API to allow CORS requests from whatever domain you use:

```yaml
api:
  cors:
    extraOrigins: 'https://dashboard.example.com'
```

> **Note**
> When `frontend.ingress.host` is set, the chart allows `https://` plus that host on its own. Any other origin, including a port-forward, still has to be listed in `api.cors.extraOrigins`. If the ingress host is blank, the generated origin is `https://` and does not cover the dashboard.

## Scenario 2 (Other account management, Forked dashboard)
Since `api.accounts.managed` is `true`, you can create and delete users as necessary using the Admin API (see [create](https://safesurfer.gitlab.io/admin-app-api-docs/#tag/users/operation/postUser), [delete](https://safesurfer.gitlab.io/admin-app-api-docs/#tag/users/operation/deleteUser)). To transfer auth to the frontend, use the [signin token API](https://safesurfer.gitlab.io/admin-app-api-docs/#tag/users/operation/postSigninToken). The form field `expiry` is a unix time, and the response `spec` is the token string. Pass it to the frontend as `https://frontend.ss.example.com/start?signin-token=${SIGNIN_TOKEN}`. `/login` forwards that query to `/start` in the app. The frontend then calls `GET /v2/user/auth/token/from-signin-token?signin-token=`. That token works once; a second request is rejected. Some frontend customization will be needed to remove the login form, handle what happens when the token expires, etc. Branding for a fork of the reference dashboard is `src/helpers/whitelabel.ts` plus the `BRAND_NAME`, `PLAN_NAME`, `ROUTER_NAME`, `HELP_URL`, `CONTACT_URL`, `PRIVACY_POLICY_URL`, and `TERMS_AND_CONDITIONS_URL` tokens.

Device auth can still be obtained with a `role` on that signin token, or through the [QR auth](https://safesurfer.gitlab.io/api-docs/#tag/userv2/operation/postQrSigninToken) or [remote auth](https://safesurfer.gitlab.io/api-docs/#tag/userv2/operation/postUserAuthRemoteRequest) flows.

## Scenario 3 (Safe Surfer is account management, Own dashboard (backend rendering or frontend+backend))
If the custom dashboard will be backend-rendered (like PHP or Django apps, for instance), you can simply request the regular API service. After signing in, you could return the auth token as a cookie, or store it somewhere else and use some other session tracking. Then you can use the auth token to make API requests to render pages as needed.

If you need some frontend rendering, you could return the auth token directly to the user or proxy requests to the API using your backend.

See the [API docs](https://safesurfer.gitlab.io/api-docs) for more implementation details.

If you don't want to expose the API to the internet at all, leave `api.ingress` disabled when the dashboard runs in the same cluster. To publish the API and allow only your backend, set `api.ingress.class` to `traefik` and attach an IP allow list middleware. See [Restricting source IPs](./ingress-and-cert-setup.md#restricting-source-ips).

## Scenario 4 (Other account management, Own dashboard (backend rendering))
Since `api.accounts.managed` is `true`, you can create and delete users as necessary using the Admin API (see [create](https://safesurfer.gitlab.io/admin-app-api-docs/#tag/users/operation/postUser), [delete](https://safesurfer.gitlab.io/admin-app-api-docs/#tag/users/operation/deleteUser)). Once you have users, the easiest thing to do is call the admin listener on behalf of a user. That listener is the Service `safesurfer-api-admin-internal` port 80 (the pod port is `api.adminPort`). The public API does not accept these headers. Set:
- `X-Safe-Surfer-Api-Admin-Secret` to the value of `api.adminSecret`. A wrong secret is rejected.
- `X-Safe-Surfer-Api-Admin-Mock-User` to the Safe Surfer user ID to act as. This is the numeric user ID.
- `X-Safe-Surfer-Api-Admin-Mock-Device` to a device ID when the route needs device auth. Account routes work without it. A device route without it is rejected, and a device the user does not own is rejected.

Normally, admin auth is only usable within the cluster, which is the most secure way to do it. You could even use a [Network Policy](https://kubernetes.io/docs/concepts/services-networking/network-policies/) to restrict traffic from other namespaces within the cluster.

If your dashboard must be hosted somewhere else, you can enable `api.adminIngress`. Store `api.adminSecret` carefully. The admin ingress uses `api.ingress.class` and its own `annotations`, so attach an IP allow list middleware there too. See [Restricting source IPs](./ingress-and-cert-setup.md#restricting-source-ips). Admin auth is very powerful and can result in sensitive data being leaked if used incorrectly.

If you need some frontend rendering, you could proxy requests to the API using your backend, or use the [signin token API](https://safesurfer.gitlab.io/admin-app-api-docs/#tag/users/operation/postSigninToken) to get a regular API auth token to return to the user directly.

See the API docs for more implementation details.

## Scenario 5 (Safe Surfer is account management, Own dashboard (frontend rendering))
In this scenario, the browser signs in with `POST /v2/user/auth/token` and then calls the API with that token. The default dashboard is a useful reference. This route is not registered when `api.accounts.managed` is true.

## Scenario 6 (Other account management, Own dashboard (frontend rendering))
In this scenario, your backend checks the user and then requests a [signin token](https://safesurfer.gitlab.io/admin-app-api-docs/#tag/users/operation/postSigninToken). The browser trades it once with `GET /v2/user/auth/token/from-signin-token?signin-token=`. The default dashboard is a useful reference for that exchange.
