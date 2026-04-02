---
description: "Global rules for the agentrc project."
---

# Global Copilot Instructions

## Webapp Deployment Instructions — Auto-Update Rule

Whenever you modify any file matching the patterns below, review `.github/instructions/webapp-deploy.instructions.md` and update it if the change affects deployment behavior:

- `webapp/**` — frontend or backend code, dependencies, config
- `Dockerfile.webapp` — container build instructions
- `infra/webapp/**` — Bicep infrastructure templates
- `packages/core/src/**` — shared library bundled into the backend

Changes that require updating the deployment instructions include:

- New environment variables or secrets added to the container app
- New files or directories that the Dockerfile copies
- Changes to the esbuild config or build pipeline
- New Azure resources in the Bicep template
- Changes to the ACR registry name, container app name, or resource group
- Changes to dependency structure (new `package.json` files copied in Docker build)
- New probes, scaling rules, or ingress configuration

Do NOT update the deployment instructions for changes that are purely internal (test files, local dev config, code logic that doesn't affect the build/deploy pipeline).
