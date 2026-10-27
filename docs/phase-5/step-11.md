# Phase 5 · Step 11 — App Service Bicep module

## What changed

- Added `infra/modules/appservice.bicep` for static web hosting.

## Why

Provides App Service infra for frontend deployment.

## ELI5

A home for the website on Azure.

## Validate

```bash
az bicep build --file infra/modules/appservice.bicep
```

Expected: no errors.
