# Step 6 — Cheapest OpenAI model

Use cheapest model deployment name in params (gpt-4o-mini). Configure in provision scripts/params; no Bicep change here.

## Validate

az bicep build --file infra/main.bicep
