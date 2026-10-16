# Traefik Client-Facing Read/Write Timeouts: Can They Be Overridden Per Ingress/Application?

**Short answer: Not for the existing client-facing timeouts.** Entrypoint `readTimeout`/`writeTimeout` are static, entrypoint-scoped settings applied to the
`web`/`websecure` entryPoints at Traefik startup. They cannot be set per Kubernetes `Ingress`, per `IngressRoute`,
per router, or per middleware. `ServersTransport` (CRD or annotation) only changes how Traefik talks to the
**backend**, not how long it will wait while writing the response back to the **client** — it does not bypass or
extend the entrypoint `writeTimeout`.

## Resolved version

- Repo pins Helm chart `traefik` **40.2.0** (`apps/admin/traefik2/traefik2.yaml:16`, `version: 40.2.0`).
- The image is `hmctsprod.azurecr.io/imported/traefik` with **no explicit tag** (`apps/admin/traefik2/traefik2.yaml`), so the chart's default `appVersion` applies.
- Chart.yaml at tag `v40.2.0` (upstream `traefik/traefik-helm-chart`):
  `https://raw.githubusercontent.com/traefik/traefik-helm-chart/v40.2.0/traefik/Chart.yaml`
  ```yaml
  version: 40.2.0
  appVersion: v3.7.1
  annotations:
    traefik.io/proxy-min-version: v3.6.0
    traefik.io/proxy-max-version: v3.7.1
  ```
  → **Traefik proxy v3.7.1** (compatible range v3.6.0–v3.7.1). All findings below are verified against the
  official **Traefik v3.7** docs tree (`doc.traefik.io/traefik/reference/...`, backed by
  `github.com/traefik/traefik` branch `v3.7`).

## Repo facts

- `apps/admin/traefik2/traefik2.yaml:70-76` — `additionalArguments`:
  - `--entryPoints.web.transport.respondingTimeouts.writeTimeout=30`
  - `--entryPoints.websecure.transport.respondingTimeouts.writeTimeout=30`
  - `--entryPoints.web.transport.respondingTimeouts.readTimeout=30`
  - `--entryPoints.websecure.transport.respondingTimeouts.readTimeout=30`
  - (plus `forwardedHeaders.insecure=true` for both entrypoints)
- `apps/admin/traefik2/traefik2.yaml:48-49` — `kubernetesIngress.publishedService` enabled.
- `apps/admin/traefik2/traefik2.yaml:53-57` configures the disabled dashboard IngressRoute; its entrypoint list does not set application router defaults.

These four `additionalArguments` are command-line flags to the Traefik binary, configuring the **static**
(install-time) entryPoint transport, not the dynamic (per-router/per-service) configuration that Ingress/IngressRoute/Middleware/ServersTransport objects produce.

## 1. EntryPoint `transport.respondingTimeouts` — static, not overridable per router

Official reference (v3.7): `https://doc.traefik.io/traefik/reference/install-configuration/entrypoints/`
(source: `https://github.com/traefik/traefik/blob/v3.7/docs/content/reference/install-configuration/entrypoints.md`)

| Field | Meaning | Default |
|---|---|---|
| `transport.respondingTimeouts.readTimeout` | Max duration to read the entire incoming request (incl. body). 0 = no timeout. | **60s** |
| `transport.respondingTimeouts.writeTimeout` | Max duration from end-of-request-header-read to end-of-response-write. 0 = no timeout. | **0s (disabled)** |
| `transport.respondingTimeouts.idleTimeout` | Max time to wait for the next request on a keep-alive connection. | 180s |

These fields live **under the EntryPoint**, which is a *static* configuration object defined at Traefik
process start (CLI flags / `traefik.yaml` / Helm `additionalArguments` or `ports`/`entryPoints` values — all
rendered once into the static config). There is **no field on `Ingress`, `IngressRoute`, `HTTPRoute`, router,
or Middleware** that sets `respondingTimeouts`. Setting it anywhere other than the entrypoint level is not a
supported schema option — confirmed by it only appearing under
`reference/install-configuration/entrypoints/` and nowhere in the dynamic/routing-configuration reference
tree (`reference/routing-configuration/http/...`, `reference/routing-configuration/kubernetes/...`).

Consequence for this repo: the `=30` read/write timeout is a single, cluster-wide (or rather,
Traefik-instance-wide) ceiling applied identically to **every** Ingress/IngressRoute/Service routed through
the `web`/`websecure` entrypoints on this Traefik deployment. No per-Ingress or per-application annotation can
raise or lower it.

## 2. Router-level selection is not a timeout override

Routers can select entrypoints, but do not expose a `respondingTimeouts` override.
`transport.respondingTimeouts` belongs to the listener configuration, not the router.
Sources: the entrypoints reference above and the Kubernetes Ingress annotations reference below.

## 3. `ServersTransport` — backend transport only, never touches entrypoint timeouts

Official reference (v3.7): `https://doc.traefik.io/traefik/reference/routing-configuration/http/load-balancing/serverstransport/`
(Kubernetes CRD variant: `https://github.com/traefik/traefik/blob/v3.7/docs/content/reference/routing-configuration/kubernetes/crd/http/serverstransport.md`)

`ServersTransport` configures **the connection between Traefik and your HTTP backend servers** (TLS
verification, mTLS, cipher suites, HTTP/2, and `forwardingTimeouts`):

| Field | Meaning | Default |
|---|---|---|
| `forwardingTimeouts.dialTimeout` | Time to wait for a TCP connection to the backend server. | 30s |
| `forwardingTimeouts.responseHeaderTimeout` | Time to wait for the backend's **response headers** after the request (incl. body) has been fully written. | 0s (disabled) |
| `forwardingTimeouts.idleConnTimeout` | Max idle time for a kept-alive connection to a backend. | 90s |
| `forwardingTimeouts.readIdleTimeout` / `pingTimeout` | HTTP/2 backend keep-alive ping behaviour, not an application response deadline. | See the relevant transport reference |

Attachment points (official, v3.7):
- Ordinary **Ingress**, via a Service annotation:
  `traefik.ingress.kubernetes.io/service.serverstransport` → value `namespace-name@kubernetescrd` (or `name@file`).
  Source: `https://github.com/traefik/traefik/blob/v3.7/docs/content/reference/routing-configuration/kubernetes/ingress.md`
  (`### On Service` table, `service.serverstransport` row). This annotation is read **only when the Service is
  used directly as an Ingress backend** — it is explicitly documented as *not* applied when the Service is
  referenced from a Middleware (e.g. ErrorPages) — the ServersTransport must be set in the middleware
  definition in that case.
- **IngressRoute** CRD: `spec.routes[].services[].serversTransport` (service-level field, CRD kind
  `ServersTransport`). Source: `https://github.com/traefik/traefik/blob/v3.7/docs/content/reference/routing-configuration/kubernetes/crd/http/serverstransport.md`.
- **TraefikService** CRD: top-level `serverstransport` field (same source as above).

**Namespace / CRD prerequisites:**
- `ServersTransport` is a Traefik CRD kind; it requires the Traefik Kubernetes CRD definitions + RBAC to be
  installed (`providers.kubernetesCRD` provider), per
  `https://doc.traefik.io/traefik/reference/install-configuration/providers/kubernetes/kubernetes-crd/`.
  Install command shown there is pinned to the branch/tag matching the Traefik version, e.g.
  `kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v3.7/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml`.
  The repo installs the chart **v40.2.0** CRDs, including `ServersTransport`, in
  `apps/admin/traefik-crds/kustomization.yaml:4-13`. The chart enables `providers.kubernetesCRD`
  by default; this repo does not override it. RBAC is enabled in `traefik2.yaml:84-85`.
  Chart defaults: `https://github.com/traefik/traefik-helm-chart/blob/v40.2.0/traefik/values.yaml`.
- Cross-namespace reference (`namespace-name@kubernetescrd`) requires
  `providers.kubernetesCRD.allowCrossNamespace: true` at the provider level (default `false`). Without it, a
  cross-namespace `ServersTransport` reference from an `IngressRoute` is skipped/ignored with an error logged.
  Source: same kubernetes-crd reference page, `allowCrossNamespace` row, and
  `serverstransport.md`'s "Reference a ServersTransport CRD from another namespace" note.
- If `safeNaming` is enabled on the `kubernetesCRD` provider, the cross-namespace reference syntax changes to
  `namespace_name@kubernetescrd` (underscore separator).

### Explicit non-equivalence: `responseHeaderTimeout` ≠ `writeTimeout`

These two settings are frequently conflated but measure different things and sit on different sides of the proxy:

- Entrypoint `writeTimeout` (client-facing, static): starts after Traefik finishes reading the incoming
  request headers, and covers **the response write to the client**, not just the backend header wait.
  Do not extrapolate this HTTP response deadline to the lifetime of a hijacked/upgraded WebSocket connection.
- ServersTransport `responseHeaderTimeout` (backend-facing, per-service): only measures how long Traefik
  waits for the **backend** to send response **headers** after Traefik finished sending the request. Once
  headers arrive, this timer is irrelevant — it says nothing about how long the body/stream may subsequently
  take, and it does not touch the client-side write.

Because of this, **raising `responseHeaderTimeout` (or `dialTimeout`/`idleConnTimeout`) on a ServersTransport
cannot work around a 30s entrypoint `writeTimeout`.** A slow/streaming backend response that takes >30s to
fully write to the client will still be cut off at 30s by the shared `websecure`/`web` entrypoint, no matter
what ServersTransport is attached to that one Service — because the entrypoint `writeTimeout` clock started
before the ServersTransport's backend-side timers even became relevant, and continues regardless of them.

## 4. Middleware cannot override entrypoint timers

Middlewares (`Middleware`/`MiddlewareTCP` CRDs, or `traefik.ingress.kubernetes.io/router.middlewares`
annotation) operate on the **dynamic** HTTP router chain — request/response transformation, auth, headers,
rate limiting, circuit breaking, retries, etc. None of the documented middleware types
(`https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/overview/` family) expose a
field that changes `transport.respondingTimeouts`; that setting is fixed at entrypoint/listener construction
time, before any router or middleware chain is evaluated for a given request. There is no "timeout" middleware
in the v3.7 middleware catalogue that adjusts the client-facing write deadline.

## 5. Options to give one application a different client-facing timeout

Since entrypoint timeouts are static and shared by every router bound to that entrypoint, the only ways to
give a specific Ingress/app a different client read/write timeout are:

1. **Raise the shared entrypoint value** (`web`/`websecure`) for everyone — simplest, but it raises the
   ceiling for all applications on that entrypoint, including ones that don't need it (larger blast radius for
   slow/hung upstreams tying up connections, and reduced protection against slowloris-style client behaviour).
   This is the "shared entrypoint raising limit, cap per-service at the backend" pattern referenced in the
   task — it still requires a backend-side cap (e.g. an app-level timeout, or `ServersTransport.responseHeaderTimeout`
   for headers-only backend misbehaviour) layered on top, since the entrypoint change alone affects everyone.
2. **Add a separate entrypoint** (e.g. `websecure-long-timeout` on a distinct port) with its own
   `transport.respondingTimeouts`, and attach only the exception application's router(s) to it via
   `entryPoints:` on the `IngressRoute`/`Ingress` (`traefik.ingress.kubernetes.io/router.entrypoints` annotation,
   per `https://github.com/traefik/traefik/blob/v3.7/docs/content/reference/routing-configuration/kubernetes/ingress.md`,
   `router.entrypoints` row) or `spec.entryPoints` on an `IngressRoute`. This correctly isolates the longer
   timeout to one app, but has real operational cost:
   - A **new port must be opened** on the Traefik Service/LoadBalancer (Helm `ports.*` values) and exposed
     through whatever network path reaches the cluster (NSG/firewall/LB listener), i.e. a genuine
     infrastructure change, not just a Kubernetes object.
   - TLS, middlewares, forwarded-headers behaviour, etc. configured on the original entrypoint are **not**
     inherited automatically — they are static settings per entrypoint and would need to be replicated for
     the new one (see "default behaviours can be overridden in the Helm Chart" note on the entrypoints
     reference page, i.e. each entrypoint is independently configured).
   - Every exception router should explicitly select the new entrypoint. Also configure the normal
     entrypoints as the default set (`asDefault`): without an explicit default set, Traefik includes
     all eligible HTTP/TCP entrypoints for routers that omit `entryPoints`. Adding a listener alone
     does not isolate it from these routers. Source:
     `https://doc.traefik.io/traefik/reference/install-configuration/entrypoints/#asdefault`.
   - Multiplies the number of static listeners/ports to reason about, monitor and secure over time.
3. A separate **Traefik instance/deployment entirely** for the exception application, with its own static
   config — same idea as (2) but with full isolation, at the cost of running/maintaining a second controller.

There is no first-class "per-Ingress timeout override" shortcut; (1)/(2)/(3) above, or application-level
timeout handling inside the pod itself, are the only supported levers.

## 6. Illustrative YAML — ServersTransport on a plain Service (explicitly NOT a fix for the entrypoint cap)

This shows the officially documented attachment pattern. It changes **only backend dial/response-header/idle
behaviour** for this one Service; it does **not** raise, lower, or otherwise interact with the shared
`web`/`websecure` entrypoint `readTimeout=30`/`writeTimeout=30` set in `traefik2.yaml:73-76`. A request to
this service can still be cut off by the entrypoint `writeTimeout` while its body/stream is still being
written to the client, even though `responseHeaderTimeout` below is generous.

```yaml
# NOT a solution to the existing 30s client-facing read/write cap.
# Only affects how Traefik talks to the backend Pods behind `my-app-service`.
apiVersion: traefik.io/v1alpha1
kind: ServersTransport
metadata:
  name: my-app-backend-transport
  namespace: my-app-ns
spec:
  forwardingTimeouts:
    dialTimeout: 10s
    responseHeaderTimeout: 120s   # backend header wait only — NOT the client write deadline
    idleConnTimeout: 90s
---
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
  namespace: my-app-ns
  annotations:
    # Attaches the ServersTransport above when this Service is used as an
    # Ingress backend (ignored when referenced only from a Middleware).
    traefik.ingress.kubernetes.io/service.serverstransport: my-app-ns-my-app-backend-transport@kubernetescrd
spec:
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 8080
```

Equivalent `IngressRoute` form (service-level field, same CRD, same caveat applies):

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: my-app-route
  namespace: my-app-ns
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`my-app.example.com`)
      kind: Rule
      services:
        - name: my-app-service
          port: 80
          serversTransport: my-app-backend-transport
```

## Key conclusions

1. **No per-Ingress/IngressRoute override exists** for `transport.respondingTimeouts.readTimeout`/`writeTimeout`
   in Traefik v3.7 (chart 40.2.0's resolved `appVersion`). They are static, entrypoint-scoped settings set once
   at process start via Helm `additionalArguments`/`ports`/`entryPoints` values.
2. `ServersTransport` (CRD, attached via IngressRoute/TraefikService field or the
   `traefik.ingress.kubernetes.io/service.serverstransport` Ingress Service annotation) only governs the
   Traefik→backend leg (`dialTimeout`, `responseHeaderTimeout`, `idleConnTimeout`, `readIdleTimeout`,
   `pingTimeout`, plus TLS/mTLS options). It cannot raise, lower, or bypass the shared entrypoint
   `writeTimeout`/`readTimeout` that bounds the Traefik→client leg.
3. `responseHeaderTimeout` and `writeTimeout` measure different things: headers-only backend wait vs. the
   full client-facing response write (including streaming bodies). Increasing one has no bearing on the other.
4. Middlewares cannot adjust entrypoint-level timers; that layer is evaluated after the listener (and its
   static timeouts) are already fixed.
5. The only ways to give one application a genuinely different client-facing timeout are: raise the shared
   entrypoint value for all routers on it (with an app-level/backend-side cap layered on top), or stand up a
   separate entrypoint (new port, explicit `entryPoints`/`router.entrypoints` selection per router, and
   independent replication of TLS/middleware/forwarded-header static config) or a separate Traefik
   instance for the exception case.

## GitOps render verification

A `kubectl kustomize --load-restrictor=LoadRestrictionsNone` render of this repo's overlays shows:
- `apps/admin/prod/00` retains all four `additionalArguments` timeout flags (`readTimeout`/`writeTimeout` = 30
  on both entrypoints), consistent with `traefik2/traefik2.yaml:73-76`.
- `apps/admin/ptl-intsvc/00` and `apps/admin/sbox-intsvc/00` render **only** the two
  `forwardedHeaders.insecure=true` arguments — the four explicit timeout flags are **absent** from the
  rendered `additionalArguments` list in these two overlays (`traefik2/ptl-intsvc/00.yaml:10-12`,
  `traefik2/sbox-intsvc/00.yaml:11-13`), i.e. the Kustomize patch appears to **replace** rather than merge the
  `additionalArguments` list.
- Because the rendered config for ptl-intsvc/sbox-intsvc omits the explicit flags, and the Helm chart's
  `ports.web`/`ports.websecure.transport.respondingTimeouts` defaults are unset (the chart supports these
  keys, but does not supply timeout values), those two environments are expected to fall back to the
  **Traefik binary defaults** documented in §1 above:
  `readTimeout = 60s`, `writeTimeout = 0s (disabled)`. This is a materially different effective timeout
  behaviour than prod's explicit `30s`/`30s`.
- This is confirmed as the **rendered GitOps manifest state**, not a live-cluster/deployed-state
  verification — no live Azure/AKS queries were performed as part of this investigation.

**No deployment configuration changed.**

## Limitations

- Whether the ptl-intsvc/sbox-intsvc list-replacement of `additionalArguments` is deliberate (an
  intentional environment-specific relaxation) or an unintentional Kustomize patch side effect is unknown;
  this report documents the observed rendered output and its expected timeout
  consequence.
- No live cluster state (actual running Traefik pod args, actual listening ports) was queried; all
  verification here is against the GitOps source/render and official upstream docs/source only.
- Did not find a Traefik v3.7 changelog entry introducing any new per-router or per-service override for
  `respondingTimeouts`; absence-of-feature conclusion is based on the full v3.7 reference doc tree not
  containing such a field anywhere outside the entrypoint page, not on an explicit "not supported" statement
  from Traefik maintainers.

## Citations

- Chart pin & additionalArguments (repo): `apps/admin/traefik2/traefik2.yaml:16,48-49,70-76`
- Chart version → Traefik version: `https://raw.githubusercontent.com/traefik/traefik-helm-chart/v40.2.0/traefik/Chart.yaml`
- EntryPoints reference (readTimeout/writeTimeout, http.middlewares/tls override semantics):
  `https://doc.traefik.io/traefik/reference/install-configuration/entrypoints/`
  (source: `https://github.com/traefik/traefik/blob/v3.7/docs/content/reference/install-configuration/entrypoints.md`)
- Service / ServersTransport reference field: `https://doc.traefik.io/traefik/reference/routing-configuration/http/load-balancing/service/`
- ServersTransport (dynamic config) reference: `https://doc.traefik.io/traefik/reference/routing-configuration/http/load-balancing/serverstransport/`
- Kubernetes ServersTransport CRD + IngressRoute/TraefikService attachment:
  `https://github.com/traefik/traefik/blob/v3.7/docs/content/reference/routing-configuration/kubernetes/crd/http/serverstransport.md`
- Kubernetes Ingress annotations (`service.serverstransport`, `router.entrypoints`, service-annotation/middleware caveat):
  `https://github.com/traefik/traefik/blob/v3.7/docs/content/reference/routing-configuration/kubernetes/ingress.md`
- Kubernetes CRD provider (`allowCrossNamespace`, CRD/RBAC install prerequisites):
  `https://doc.traefik.io/traefik/reference/install-configuration/providers/kubernetes/kubernetes-crd/`
- Kubernetes Ingress provider (`publishedService`, provider options):
  `https://doc.traefik.io/traefik/reference/install-configuration/providers/kubernetes/kubernetes-ingress/`
