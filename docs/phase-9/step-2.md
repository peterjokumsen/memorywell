# Step 2 — Drop Redis in prod

## What changed

- `infra/modules/platform.bicep`: `includeRedis` now also excludes `prod` environment.

## Why

Removes Managed Redis cost in prod; dev/staging keep Redis for caching tests.

## ELI5

Redis (cache) is skipped when deploying to prod to save money.

## Validate

```
az bicep build --file infra/main.bicep
```
