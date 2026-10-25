# Phase 3 · Step 6 — Group F: Wiring + deploy + hygiene

**Wiring + deploy + hygiene, plus the hosting-plan switch.** Compose Service Bus /
Event Grid / Functions into `platform.bicep`, grant the Function App's managed
identity the needed roles (Service Bus Data Receiver/Sender, Cosmos Built-in Data
Contributor at database scope, Key Vault Secrets User, storage data-plane roles),
wire app settings (endpoints, Key Vault references), **move the Functions app
from Linux Consumption (Y1) to Flex Consumption (FC1)**, deploy, and verify.

## Hosting migration: Linux Consumption → Flex Consumption

Flex Consumption is a different plan and a different site shape, not a toggle:
the `Y1`/Dynamic plan becomes `FC1`/`FlexConsumption`, and `Microsoft.Web/sites`
gains `functionAppConfig`. In-place migration isn't supported, so this step
deletes the old site and lets Bicep recreate it under the same name. Keeping the
name keeps `<app>.azurewebsites.net`, so the Event Grid subscription URLs stay
valid — the second Bicep pass re-validates them anyway.

The existing `Microsoft.Web/sites@2023-12-01` already exposes
`functionAppConfig`, so no API-version bump is needed.

### Decisions to record

- **No always-ready instances (decided).** Always-ready is billed as a baseline
  whether or not anything executes, and the only timer here is a daily cadence
  sweep whose output is not user-facing. Flex still runs the timer while scaled
  to zero — the platform wakes the app for the tick — so the trade-off is a
  cold-start delay on one invocation a day, not a missed run. Leave
  `alwaysReady` unset. If the sweep ever needs to be punctual, add
  `alwaysReady: [{ name: 'timer_cadence', instanceCount: 1 }]` as its own change
  and accept the baseline cost.
  > Do not need the timer to react immediately, so cold start will be fine.
- **Keep the app name `func-<base>-<env>` (decided).** It's the Event Grid
  destination and the Bruno `fns_url`; recreating under a new name means
  re-pointing both for no benefit.
  > Keep the nme
- **Reuse the environment storage account (decided).** One LRS account, as
  today. Add a dedicated deployment container rather than sharing
  `eventgrid-dlq`.
  > Yes
- **Switch `AzureWebJobsStorage` to the managed identity in this step
  (decided).** Flex has no Azure Files requirement, so the key-based connection
  string built with `listKeys()` can go. This is the Phase 3 shortcut flagged in
  `functions.bicep`, and the migration is the natural point to remove it.
  > Agreed
- **`instanceMemoryMB: 2048`, `maximumInstanceCount: 5` (decided).** 2048 MB is
  the documented default for Python workloads; the ceiling is generous for one
  household and bounds accidental scale-out. Per-function scaling applies the
  ceiling per function group, not app-wide.
- **No deployment slots.** Flex doesn't support them; this app never used any.

### Infra changes

`infra/modules/functions.bicep` — replace the plan and site body. Shape only:

```bicep
resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: inputs.global.location
  kind: 'functionapp'
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  properties: {
    reserved: true
  }
}

resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  // identity block unchanged: user-assigned
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
    }
    functionAppConfig: {
      runtime: { name: 'python', version: '3.11' }
      scaleAndConcurrency: {
        instanceMemoryMB: 2048
        maximumInstanceCount: 5
      }
      deployment: {
        storage: {
          type: 'blobContainer'
          // must be the container URL, not just the name
          value: 'https://${storageAccountName}.blob.${environment().suffixes.storage}/${deploymentContainerName}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: identityId
          }
        }
      }
    }
  }
}
```

Delete from the site: `reserved`, `siteConfig.linuxFxVersion`,
`siteConfig.ftpsState`, and the `FUNCTIONS_EXTENSION_VERSION` /
`FUNCTIONS_WORKER_RUNTIME` app settings. Flex manages the runtime through
`functionAppConfig.runtime`; those settings are on the deprecation list and are
ignored or rejected.

Replace the `AzureWebJobsStorage` connection string (`listKeys()` + account key)
with an identity-based connection:

```bicep
{ name: 'AzureWebJobsStorage__accountName', value: storageAccountName }
{ name: 'AzureWebJobsStorage__credential', value: 'managedidentity' }
{ name: 'AzureWebJobsStorage__clientId', value: identityClientId }
```

That needs the identity's **client ID** — reuse the `identityClientId` param and
`identity.outputs.clientId` threading that step 4 added for Service Bus.

`infra/modules/storage.bicep` — add the deployment container next to
`eventgrid-dlq` (suggested name `app-package-func-<base>-<env>`) and output its
name. Container names must be lowercase.

`infra/modules/platform.bicep` — pass `identityClientId`, `storageAccountName`
and the deployment container name into the `functions` module. The module's
output contract (`appName`, `defaultHostname`, `logUrl`) is unchanged, so
`main.bicep`, `common.sh` and `publish-functions.sh` keep working.

**New role assignments** at the storage account scope, granted to the env
identity (none exist for storage today):

- `Storage Blob Data Owner` — host metadata, function keys, timer blob leases,
  deployment package read (superset of Blob Data Contributor).
- `Storage Table Data Contributor` — host diagnostic events.
- `Storage Queue Data Contributor` — only needed once a storage queue
  trigger/output lands; harmless to add now.

Use `principalType: 'ServicePrincipal'` and deterministic `guid()` assignment
names, as in `acr-pull.bicep`.

### Order of operations

An ARM update cannot move an existing site onto a different plan kind, so the
old app must be gone before the new template is deployed.

1. `./scripts/teardown.sh` (or delete the site and plan by hand). Teardown is
   fine here: the environment is disposable and the second pass recreates the
   Event Grid subscriptions.
2. `./scripts/provision-env.sh --bicep-only` — pass 1, no Event Grid
   subscriptions.
3. `./scripts/publish-functions.sh` — ship the code. Flex deploys a zip to the
   blob container configured in `functionAppConfig.deployment`, and Core Tools
   still performs the Python remote build. Check `func --version` is current v4
   first; the fallback is `az functionapp deployment source config-zip --build-remote true`.
4. Re-run the environment deployment with `deployEventSubscriptions=true` —
   pass 2 validates the webhook against the now-running app.

## Wiring checklist

- [x] `platform.bicep` calls `servicebus.bicep`, `eventgrid.bicep`,
      `functions.bicep` with the right params.
- [x] `main.bicep` / `main.bicepparam` thread any new params (Function App
      name, etc.) and client IP if needed.
- [x] Function App identity granted:
  - Service Bus Data Receiver (on queue) + Data Sender (where it publishes).
  - Cosmos Built-in Data Contributor at database scope (change feed reads).
  - Key Vault Secrets User (if connection strings stored).
  - Storage Blob Data Owner + Storage Table Data Contributor (host storage).
- [x] App settings: `SERVICEBUS_NAMESPACE`, `COSMOS_ENDPOINT`,
      `COSMOS_DATABASE`, `EVENTGRID_TOPIC_ENDPOINT`, Key Vault refs for any
      secrets. No secrets in repo or Bicep outputs. `AzureWebJobsStorage` is
      identity-based, not a connection string.
- [x] `scripts/provision-env.sh --bicep-only` deploys infra, then
      `scripts/publish-functions.sh` deploys code. Keep infra and code deploy
      steps distinct in the script output.
- [x] Stale "Consumption" comments and docstrings corrected in
      `functions.bicep` (including the timer claim in the header),
      `scripts/common.sh`, `scripts/publish-functions.sh`,
      `functions/function_app.py`.
- [x] `scripts/teardown.sh` still destroys everything (now including Service
      Bus, Event Grid, Functions, storage).

## Verify

- [x] `az bicep build --file infra/main.bicep` succeeds.
- [x] `az functionapp show` → state `Running`; `serverFarmId` points at the
      `FC1` plan.
- [x] `az functionapp show --query "siteConfig.linuxFxVersion"` is empty, and
      `functionAppConfig.runtime` is `python` / `3.11`.
- [x] `az functionapp config appsettings list` shows
      `AzureWebJobsStorage__accountName` / `__credential` / `__clientId` and no
      `AccountKey=` connection string.
- [x] `az role assignment list --scope <storage-id>` shows the storage roles
      for the identity.
- [x] The deployment container exists (`az storage container exists`).
- [x] The app starts and triggers register with no storage key available — the
      real test of the identity wiring.
- [x] All triggers register in the Function App (portal "Functions" list).
- [x] Event Grid validation handshake succeeds on the second pass; a test event
      reaches `/api/log`.
- [x] Timer fires at 08:00 UTC. Cold start is expected and acceptable (no
      always-ready); record the observed delay in the review-gate paste-back.
- [x] `./scripts/teardown.sh` destroys all Phase 3 resources; re-deploy from
      scratch works.
- [x] `git status --short` shows no `.env`, no secrets, no `local.settings.json`.

## Troubleshooting

- **App starts but the host won't start / every trigger errors** — storage role
  assignment hasn't propagated (up to ~10 min), or
  `AzureWebJobsStorage__clientId` holds the identity's object ID instead of its
  client ID.
- **Deployment fails with 403 on the container** — the identity lacks blob data
  access to the deployment container, or the container doesn't exist.
- **`serverFarmId` / plan-change error** — the old Consumption app still
  exists; delete the site (and plan) and redeploy.
- **Event Grid subscription creation fails validation** — pass 2 ran before the
  code was published, or the app isn't answering `/api/log`.
- **Publish rejects the app** — Core Tools too old for Flex; update to the latest v4, or fall back to `az functionapp deployment source config-zip --build-remote true`.
- **Deprecated settings silently ignored** — `linuxFxVersion`,
  `FUNCTIONS_WORKER_RUNTIME`, `FUNCTIONS_EXTENSION_VERSION`, `ftpsState`,
  `WEBSITE_RUN_FROM_PACKAGE`; remove them rather than debugging them.
