# Step 1 — Web on Azure Static Web Apps (free tier)

## What changed

- Added `infra/modules/swa.bicep` defining a `Microsoft.Web/staticSites` resource on the Free SKU.
- `infra/main.bicep`: web module now uses `swa.bicep` instead of `appservice.bicep`.

## Why

App Service (B1) costs money even idle; SWA free tier is $0 for the web frontend while keeping HTTPS + global CDN.

## ELI5

Swapped the paid web server for a free static-site host; same URL output, no monthly charge.

## Validate

```
az bicep build --file infra/main.bicep
```

Expected: build succeeds (only pre-existing dlqalert warning).
