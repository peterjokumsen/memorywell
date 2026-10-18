# Phase 3 · Step 6 — Group F: Wiring + deploy + hygiene

**Wiring + deploy + hygiene.** Compose Service Bus / Event Grid / Functions into
`platform.bicep`, grant the Function App's managed identity the needed roles
(Service Bus Data Receiver/Sender, Cosmos Built-in Data Contributor at database
scope, Key Vault Secrets User), wire app settings (endpoints, Key Vault
references), deploy, and verify.

## Wiring checklist

- [ ] `platform.bicep` calls `servicebus.bicep`, `eventgrid.bicep`,
      `functions.bicep` with the right params.
- [ ] `main.bicep` / `main.bicepparam` thread any new params (Function App
      name, etc.) and client IP if needed.
- [ ] Function App identity granted:
  - Service Bus Data Receiver (on queue) + Data Sender (where it publishes).
  - Cosmos Built-in Data Contributor at database scope (change feed reads).
  - Key Vault Secrets User (if connection strings stored).
- [ ] App settings: `SERVICEBUS_NAMESPACE`, `COSMOS_ENDPOINT`,
      `COSMOS_DATABASE`, `EVENTGRID_TOPIC_ENDPOINT`, Key Vault refs for any
      secrets. No secrets in repo or Bicep outputs.
- [ ] `scripts/deploy.sh` deploys Functions code (zip deploy or
      `func azure functionapp publish`) after infra. Keep infra and code deploy
      steps distinct in the script output.
- [ ] `scripts/teardown.sh` still destroys everything (now including Service
      Bus, Event Grid, Functions, storage).

## Verify

- [ ] `az bicep build --file infra/main.bicep` succeeds.
- [ ] `./scripts/deploy.sh` succeeds end-to-end; Function App reachable.
- [ ] All triggers register in the Function App (portal "Functions" list).
- [ ] `./scripts/teardown.sh` destroys all Phase 3 resources; re-deploy from
      scratch works.
- [ ] `git status --short` shows no `.env`, no secrets, no `local.settings.json`.
