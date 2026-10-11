# nextjs1

A Next.js UI on CLX Static Web Apps

Next.js 16 UI (hybrid rendering, `output: "standalone"`) on Azure Static Web Apps, calling the `store-bff` BFF through APIM. Created from the `nextjs-web-app` Backstage template; owned by `group:default/guests`.

| | dev | qa |
|---|---|---|
| Static Web App | `swa-lab-nextjs1-d01` | `swa-lab-nextjs1-q01` |
| Resource group | `rg-platform-services` | `rg-platform-services` |
| Deploys from | push to `dev` | push to `qa` (pull request from `dev`), after approval |

The URL is the Static Web App's default hostname, shown in each pipeline run's summary. A custom domain through Front Door is a platform-team request.

## How it calls the BFF
```
browser ──► this app ──/api/bff/<path>──► Next.js server ──+ subscription key──► APIM /store-bff/<path> ──► BFF
```
- Pages call `/api/bff/...` on this app, never the BFF directly (see `src/app/bff-status.tsx`). The server-side proxy (`src/lib/bff.ts`) adds the APIM subscription key, so the key never reaches the browser and the BFF needs no CORS rules.
- `infra/` creates an APIM subscription for this UI in each environment, scoped to the BFF's API only, and passes its key to the server as the app setting `BFF_SUBSCRIPTION_KEY`. The key is never in git, the pipeline or a parameter file. To rotate it, regenerate the key on the subscription (`swa-lab-nextjs1-d01`) in APIM and rerun the pipeline.
- The BFF has to be published through APIM in an environment before this UI can deploy there.

## Run locally
Create `.env.local` (git-ignored) with the BFF URL and a key from your own APIM subscription:
```
BFF_BASE_URL=https://apim-samgp-lab.azure-api.net/store-bff
BFF_SUBSCRIPTION_KEY=<your key>
```
```bash
npm ci
npm run dev        # http://localhost:3000
npm test
```

## How it ships
`.github/workflows/ci-cd.yaml` calls the shared platform pipeline (`sampgreenwell-cyber/platform-workflows`, `bicep-static-web-app.yaml@v1`):
1. **Pull request:** build and test (`npm test`, `npm run build`), Snyk code and dependency scans. Nothing is deployed. Pull requests into `qa` must come from `dev`.
2. **Push to `dev`:** deploys `infra/` to dev, builds with `.env.dev` and uploads.
3. **Promotion:** open a pull request from `dev` into `qa`. After it merges, the qa deployment waits until a member of `group:default/guests` approves it in the Actions run. It only deploys code that's already on `dev`.

Each deploy is checked: `/api/health` must report the version the run just built, and `/api/bff/health` must reach the BFF through APIM. `NEXT_PUBLIC_*` values are compiled in, which is why each environment has its own build.

## Common changes
- **A browser-side setting:** add `NEXT_PUBLIC_MY_SETTING=...` to `.env.dev` and `.env.qa`. It ends up in the JavaScript bundle, so never a secret.
- **A server-side setting:** add it to `appSettings` in each `infra/<env>.bicepparam`.
- **Call the BFF through Front Door** (WAF, as VxCommerce.UI does): set `bffBaseUrl` in the parameter files.
- **Only accept traffic from Front Door:** add `staticwebapp.config.dev.json` / `staticwebapp.config.qa.json` with `networking.allowedIpRanges` and `forwardingGateway` (see VxCommerce.UI). The pipeline copies the file for the environment it deploys.

Preview an infrastructure change locally (needs Reader on the resource group):
```powershell
az deployment group what-if -g rg-platform-services -f infra/main.bicep -p infra/dev.bicepparam
```

## Platform contract
The shared pipeline relies on these; keep them in place:
- `package.json` + `package-lock.json` with a `build` script (and `test`, which the pipeline runs if present).
- `GET /api/health` returning `{"version": NEXT_PUBLIC_APP_VERSION}`, and the `/api/bff/*` proxy.
- `.env.dev` and `.env.qa`; `infra/main.bicep` plus `infra/dev.bicepparam` and `infra/qa.bicepparam`.
- `infra/modules/` is copied from `sampgreenwell-cyber/platform-bicep-modules`; update it from there.
