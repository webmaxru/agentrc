---
description: "Webapp deployment guide. Determines the MINIMUM deployment steps needed based on which files changed. Covers infra (Bicep), Docker image (ACR build), and container app update."
applyTo: "webapp/**,Dockerfile.webapp,infra/webapp/**,packages/core/src/**"
---

# Webapp Deployment — Minimum Required Actions

When the user asks to deploy the webapp, determine the **minimum set of actions** needed based on which files changed. Do NOT run a full deployment every time. Use the decision tree below.

## Azure Resource Names

| Resource         | Name / Value                    |
| ---------------- | ------------------------------- |
| Resource group   | `agentrc-webapp`                |
| Container App    | `agentrc-webapp`                |
| ACR registry     | `agentrcwebapp`                 |
| Image repository | `agentrc-webapp`                |
| Custom domain    | `agentrc.isainative.dev`        |
| Dockerfile       | `Dockerfile.webapp` (repo root) |
| Bicep entrypoint | `infra/webapp/main.bicep`       |
| Bicep params     | `infra/webapp/main.bicepparam`  |

## Decision Tree — What Changed → What to Do

### 1. Infrastructure changes (`infra/webapp/**`)

Files: `infra/webapp/main.bicep`, `infra/webapp/main.bicepparam`

These change Azure resources (Container Apps Environment, ACR, storage, networking, secrets, probes, scale rules, custom domain). **Full infra redeployment required.**

```sh
# Validate first
az bicep build --file infra/webapp/main.bicep

# Deploy infrastructure
az deployment group create \
  --resource-group agentrc-webapp \
  --template-file infra/webapp/main.bicep \
  --parameters infra/webapp/main.bicepparam

# If container image also changed, follow steps 2+3 after.
# If only infra params changed (e.g. scaling, domain), this is sufficient.
```

### 2. Docker build required (image rebuild + push to ACR)

A new container image must be built when **any** of these files changed:

| Path pattern                       | Reason                                            |
| ---------------------------------- | ------------------------------------------------- |
| `Dockerfile.webapp`                | Build instructions themselves changed             |
| `webapp/backend/src/**`            | Backend application code (bundled by esbuild)     |
| `webapp/backend/esbuild.config.js` | Build config for backend bundle                   |
| `webapp/backend/package.json`      | Backend dependencies                              |
| `webapp/backend/package-lock.json` | Backend dependency lockfile                       |
| `webapp/frontend/**`               | Static frontend files (copied into image as-is)   |
| `packages/core/src/**`             | Shared core library (aliased into backend bundle) |
| `package.json` (root)              | Root workspace dependencies                       |
| `package-lock.json` (root)         | Root workspace lockfile                           |

Build command — run from repo root:

```sh
az acr build \
  --registry agentrcwebapp \
  --image agentrc-webapp:<tag> \
  --file Dockerfile.webapp .
```

Pick a descriptive `<tag>` for the change (e.g. `fix-og-meta`, `update-styles`), or use `latest`.

**After building, always proceed to step 3.**

### 3. Container App update (deploy new image)

After pushing a new image to ACR, update the running container:

```sh
az containerapp update \
  --name agentrc-webapp \
  --resource-group agentrc-webapp \
  --image agentrcwebapp.azurecr.io/agentrc-webapp:<tag>
```

Use the same `<tag>` from step 2. This is the only step needed when the image tag changed but no infra changes occurred.

## Quick Reference — Change → Minimum Actions

| What changed                                 | Actions needed                        |
| -------------------------------------------- | ------------------------------------- |
| `webapp/frontend/` only (HTML/CSS/JS/assets) | ACR build → App update                |
| `webapp/backend/src/` only                   | ACR build → App update                |
| `packages/core/src/` only                    | ACR build → App update                |
| `Dockerfile.webapp`                          | ACR build → App update                |
| `webapp/backend/package.json` (deps)         | ACR build → App update                |
| `infra/webapp/main.bicep` (resources)        | Bicep deploy                          |
| `infra/webapp/main.bicepparam` (params)      | Bicep deploy                          |
| Infra + app code together                    | Bicep deploy → ACR build → App update |
| `webapp/backend/tests/**` only               | No deployment needed                  |
| `webapp/frontend/tests/**` only              | No deployment needed                  |
| `webapp/backend/vitest.config.js` only       | No deployment needed                  |
| `webapp/frontend/vitest.config.js` only      | No deployment needed                  |
| `webapp/docker-compose.yml` only             | No deployment needed (local dev only) |
| `webapp/.env` or `webapp/.env.example`       | No deployment needed (local dev only) |

## Build Pipeline Details

The Docker build has three stages:

1. **deps** — `npm ci` for root workspace + backend (installs `@agentrc/core` from `packages/core/`)
2. **build** — `node esbuild.config.js` bundles `webapp/backend/src/server.js` → `dist/server.js`, resolving `@agentrc/core` via alias to `packages/core/src/`
3. **runtime** — Node 24 Alpine, copies `dist/`, `node_modules/`, and `webapp/frontend/` (served as static files by Express)

The frontend has no build step — files in `webapp/frontend/` are served directly by `express.static`.

## Pre-deploy Checklist

Before deploying, run backend tests to verify the change:

```sh
cd webapp/backend && npx vitest run
```

If frontend tests exist:

```sh
cd webapp/frontend && npx vitest run
```

## Container App Architecture

- **Hosting**: Azure Container Apps (Consumption, East US)
- **Ingress**: External, port 3000, HTTPS only
- **Identity**: User-assigned managed identity for ACR pull (no admin credentials)
- **Storage**: Azure Files mount at `/app/data` for shared reports
- **Monitoring**: Application Insights via connection string secret
- **Scaling**: 1–4 replicas, HTTP-based autoscaling
- **Health**: Liveness + Readiness probes on `/api/health`
