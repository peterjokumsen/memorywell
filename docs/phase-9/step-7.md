# Step 7 — Budget alert

Added infra/modules/budget.bicep and wired into main.bicep with $50 monthly cap and 80% notification.

## Validate

az bicep build --file infra/main.bicep
