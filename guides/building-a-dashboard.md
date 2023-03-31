# Building a dashboard
The Safe Surfer deployment provides many useful APIs to users, and also a default [dashboard](https://gitlab.com/safesurfer/dashboard) implementation to utilize them. But you may wish to take a different approach, such as integrating the APIs into your own dashboard.

There are two main variables to consider here:
- Is Safe Surfer managing the user accounts (e.g. `api.accounts.managed` is `false`), or do you already have your own account management? (e.g. `api.accounts.managed` is `true`)
- Will the custom dashboard be frontend or backend rendered, or both?
- Will the custom dashboard be hosted within the same Kubernetes cluster as the Safe Surfer deployment?

We can visualize this with a table:

|        | Safe Surfer is account management | Other account management |
| ------ | ------ | ------ |
| Forked dashboard | Scenario 1 | Scenario 2 |
| Own dashboard (backend rendering or frontend+backend) | Scenario 3 | Scenario 4 |
| Own dashboard (frontend rendering) | Scenario 5 | Scenario 6 |

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
> When hosting internally, CORS settings are updated for you.

## Scenario 2 (Other account management, Forked dashboard)
Since `api.accounts.managed` is `true`, you can create and delete users as necessary using the Admin API (see [create](https://safesurfer.gitlab.io/core/admin-app-api-docs/#tag/users/operation/postUser), [delete](https://safesurfer.gitlab.io/core/admin-app-api-docs/#tag/users/operation/deleteUser)). To transfer auth to the frontend, you can use the [signin token API](https://safesurfer.gitlab.io/core/admin-app-api-docs/#tag/users/operation/postSigninToken), then pass the signin token to the frontend using the URL format `https://frontend.ss.example.com/login?signin-token=${SIGNIN_TOKEN}`. The frontend will then trade the signin token for a user API auth token. Some frontend customization will be needed to remove the login form, handle what happens when the token expires, etc.

Device auth tokens can still obtained with the signin token API too, or the QR auth or remote auth flows can still be used.

## Scenario 3 (Safe Surfer is account management, Own dashboard (backend rendering or frontend+backend))
If the custom dashboard will be backend-rendered (like PHP or Django apps, for instance), you can simply request the regular API service. After signing in, you could return the auth token as a cookie, or store it somewhere else and use some other session tracking. Then you can use the auth token to make API requests to render pages as needed.

If you need some frontend rendering, you could return the auth token directly to the user or proxy requests to the API using your backend.

See the API docs for more implementation details.

If you don't want to expose the API to the internet at all, you can leave `api.ingress` disabled if hosting the dashboard from within the same cluster, or set `api.ingress.whitelistSourceRange` to only allow your backend to request it.

## Scenario 4 (Other account management, Own dashboard (backend rendering))
Since `api.accounts.managed` is `true`, you can create and delete users as necessary using the Admin API (see [create](https://safesurfer.gitlab.io/core/admin-app-api-docs/#tag/users/operation/postUser), [delete](https://safesurfer.gitlab.io/core/admin-app-api-docs/#tag/users/operation/deleteUser)). Once you have users, the easiest thing to do is use admin auth on the user API to perform actions on behalf of users. To do this, you need to set the following headers on the API request:
- `X-Safe-Surfer-Api-Admin-Secret` should be set to the strong password you set under `api.adminSecret`.
- `X-Safe-Surfer-Api-Admin-Mock-User` should be set to the Safe Surfer user ID you want to make the request on behalf of.
- `X-Safe-Surfer-Api-Admin-Mock-Device` should be set to the Device ID of the user to make the request on behalf of. This is only needed for device-specific API endpoints.

Normally, admin auth is only usable within the cluster, which is the most secure way to do it. You could even use a [Network Policy](https://kubernetes.io/docs/concepts/services-networking/network-policies/) to restrict traffic from other namespaces within the cluster.

If your dashboard must be hosted somewhere else, you can enable the `api.adminIngress`, but you must be very careful in storing the `api.adminSecret` and also set `api.adminIngress.whitelistSourceRange` appropriately. Admin auth is very powerful and can result in sensitive data being leaked if used incorrectly.

If you need some frontend rendering, you could proxy requests to the API using your backend, or use the [signin token API](https://safesurfer.gitlab.io/core/admin-app-api-docs/#tag/users/operation/postSigninToken) to get a regular API auth token to return to the user directly.

See the API docs for more implementation details.

## Scenario 5 (Safe Surfer is account management, Own dashboard (frontend rendering))
In this scenario, you can request the API for an auth token, then use the auth token. The default dashboard would be a useful reference.

## Scenario 6 (Other account management, Own dashboard (frontend rendering))
In this scenario, you should delegate to your own backend to obtain a [signin token](https://safesurfer.gitlab.io/core/admin-app-api-docs/#tag/users/operation/postSigninToken) to the Safe Surfer API if the user's details are correct. Then, trade the signin token for a Safe Surfer API auth token. The default dashboard would be a useful reference for actual implementation.
