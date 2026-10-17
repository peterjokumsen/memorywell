# CI scheduled teardown

`scripts/teardown.sh` is meant to run between study sessions. This workflow runs
it for you: **nightly at 02:00 UTC** it deletes the environment resource group
(`rg-<base>-<env>`, e.g. `rg-memwell-dev`) and purges the soft-deleted Key Vault
so the next `deploy.sh` can recreate it under the same name.

The shared resource group (`rg-<base>-shared`, holding the ACR) is **kept** by
default — see [Shared RG lock](#shared-rg-lock).

Setup is one-time and manual: Azure app registration + RBAC, then GitHub
environment/secrets/variables.

---

## 1. Azure: service principal and RBAC

The workflow authenticates with **OIDC workload identity federation** — there is
no client secret stored anywhere, and the identity can only be used by this
repository.

### 1.1 Create the app registration

```bash
APP_ID=$(az ad sp create-for-rbac \
  --name sp-memorywell-teardown \
  --query appId -o tsv)
TENANT_ID=$(az ad sp show --id "$APP_ID" --query tenantId -o tsv)
echo "client_id=$APP_ID"
echo "tenant_id=$TENANT_ID"
```

`create-for-rbac` does not create a password. Copy `client_id` and
`tenant_id` — both are needed below.

### 1.2 Role assignments

Assign at **subscription** scope: the environment RG is deleted by this
identity, so an RG-scoped assignment would not survive long enough to be useful,
and `--shared` targets a different RG.

```bash
SUBSCRIPTION_ID=<your subscription id>

# Use the service principal's **object id**, not the app (client) id. For this
# app they differ (appId 2c8826d7-…, objectId 281d183d-…), so assigning to
# $APP_ID succeeds but silently binds to nothing.
SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)
echo "$SP_OBJECT_ID"

az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

| Role                  | Needed for                                    |
| --------------------- | --------------------------------------------- |
| Contributor           | `az group delete` on the env and shared RGs   |
| Key Vault Contributor | `az keyvault purge` on the soft-deleted vault |

Verify (RBAC propagation can take up to ~5 minutes). Check `principalId` in the
output — it must equal `$SP_OBJECT_ID`. Filtering by `--assignee` returns an empty
list here even when the assignments exist, so scope-and-filter instead:

```bash
az role assignment list --scope "/subscriptions/$SUBSCRIPTION_ID" \
  --query "[?principalId=='$SP_OBJECT_ID'].{role:roleDefinitionName, scope:scope}" -o table
```

If `az keyvault purge` is refused with an authorization error, add **Owner** at
the same subscription scope — purge of a soft-deleted vault is evaluated against
the deleted resource, and some subscriptions block it for Contributor.

### 1.3 Federated credential

```bash
# Get the exact subject GitHub will present — do not hand-write it.
OWNER_ID=$(gh api repos/<your-github-user>/memorywell --jq .owner.id)
REPO_ID=$(gh api repos/<your-github-user>/memorywell --jq .id)

# with cred.json:
{
  "name": "memorywell-teardown-env-azure",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<your-github-user>@$OWNER_ID/memorywell@$REPO_ID:environment:azure",
  "audiences": ["api://AzureADTokenExchange"]
}

az ad app federated-credential create \
  --parameters cred.json \
  --id "$APP_ID"
```

The `subject` **must** match the GitHub environment name in
[step 2](#2-github-environment-secrets-and-variables) character for character —
and the `environment:azure` segment means the subject only works if the
`azure` environment exists and is attached to the job.

GitHub includes the **numeric owner and repo ids** in the subject
(`repo:owner@12345/repo@67890:environment:azure`). The older id-less form
(`repo:owner/repo:environment:azure`) is not what is presented any more, and
login fails with:

```
AADSTS700213: No matching federated identity record found for presented
assertion subject 'repo:...'
```

Get the ids with `gh api repos/<owner>/<repo> --jq .id` (and `.owner.id`) as
above. If an id-less credential already exists it can be deleted:

```bash
az ad app federated-credential delete --id "$APP_ID" \
  --parameters memorywell-teardown-main
```

---

## 2. GitHub: environment, secrets and variables

Repo → **Settings** → **Environments** → **New environment**, named `azure`.
Add a **secret**:

| Name                    | Value                                  |
| ----------------------- | -------------------------------------- |
| `AZURE_SUBSCRIPTION_ID` | Subscription containing `rg-memwell-*` |
| `AZURE_CLIENT_ID`       | app id from 1.1                        |
| `AZURE_TENANT_ID`       | tenant id from 1.1                     |

All three must be **secrets**, not variables — the workflow reads them via
`${{ secrets.* }}`. Stored as variables the OIDC login step gets empty values
and fails with `Not all values are present. Ensure 'client-id' and 'tenant-id'
are supplied`.

Repository-level secrets work too (an environment secret shadows a repository
one, and `${{ secrets.* }}` falls back to repository scope), so
`AZURE_CLIENT_ID` / `AZURE_TENANT_ID` may live under **Settings → Secrets and
variables → Actions → Secrets** instead. `AZURE_SUBSCRIPTION_ID` is the one to
keep on the `azure` environment, since it is subscription-specific.

```bash
# sanity check that all three resolve, after saving them
gh secret list
gh secret list --env azure
```

Add **variables** (Settings → Secrets and variables → Actions → Variables tab):

| Name          | Value        | Notes                    |
| ------------- | ------------ | ------------------------ |
| `BASE_NAME`   | `memwell`    | must match your `.env`   |
| `LOCATION`    | `westeurope` | must match your `.env`   |
| `SHARED_LOCK` | `true`       | see below                |
| `ENVIRONMENT` | `dev`        | fallback for manual runs |

### Shared RG lock

`SHARED_LOCK` controls what happens to `rg-<base>-shared` (the ACR):

| `SHARED_LOCK`                   | Scheduled nightly run | Manual run with `delete_shared: false` |
| ------------------------------- | --------------------- | -------------------------------------- |
| `true`                          | kept                  | kept                                   |
| anything else (default:`false`) | deleted               | kept                                   |
| any + `delete_shared: true`     | —                     | deleted                                |

Since ACR has a cost, for now keeping this at `false` as environment variable.
When shared RG is needed for environments other than `dev`, should switch this to `true`.

Note that `az login`/RBAC aside, the ACR deletion is what makes the next deploy
slow — recreate it with `./scripts/deploy-shared.sh`.

---

## 3. First run

1. Trigger **Actions → scheduled-teardown → Run workflow** with `dry_run: true`.
   The log should print `rg-memwell-dev`, `kv-memwell-dev` and the shared
   decision, and touch nothing in Azure.
2. Run again with `dry_run: false`. Expect the RG delete, the vault purge
   (waiting; the **Verify** step allows up to 30 min for the managed
   environment to drain, logging progress every few checks), and a green
   **Verify** step. Script messages arrive as Actions annotations, and the
   vault wait sits inside a collapsible group — expand it only when it fails.
3. Confirm in the portal that `rg-memwell-dev` is gone and
   `rg-memwell-shared` still exists.
4. Confirm the next `./scripts/deploy.sh` succeeds — that is the real proof the
   vault was purged (an un-purged vault blocks the same name).

## 4. Pausing / operating

- **Pause the nightlies:** GitHub → repo → Actions → `scheduled-teardown` →
  **Disable workflow**. Re-enable before your next study session.
- **Rebuild:** `./scripts/deploy.sh` (plus `./scripts/deploy-shared.sh` if the
  shared RG is gone).
- **Long inactivity:** GitHub disables scheduled workflows on repos with no
  activity for 60 days, so the nightly simply stops running. Check the Actions
  tab after a long break.
- **Rerun just the verification:** none needed — rerun the whole job; the RG
  delete is a no-op when the group is absent.

## 5. Troubleshooting

| Symptom                                              | Cause / fix                                                                                               |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `AADSTS70021: No matching federated identity record` | Federated-credential `subject` does not match `repo:<owner>/<repo>:environment:azure`                     |
| `AuthorizationFailed` on `az group delete`           | Role assignment missing or not yet propagated (~5 min). Re-check with the verify command in 1.2           |
| `Forbidden` on `az keyvault purge`                   | Add **Owner** at subscription scope (see 1.2)                                                             |
| Verify step: `still soft-deleted`                    | Purge raced the RG delete. Purge manually: `az keyvault purge --name kv-memwell-dev`                      |
| Job silently did nothing                             | Nightly schedule disabled (60-day inactivity) or workflow disabled in the Actions tab                     |
| `set: LOCATION: parameter null` style script errors  | `scripts/common.sh` requires `BASE_NAME`/`LOCATION`/`SUBSCRIPTION_ID`; confirm the GitHub variables exist |

## 6. Related

- `scripts/teardown.sh` — the script this workflow calls (flags: `--purge-vault`, `--shared`)
- `scripts/common.sh` — naming rules (`rg-<base>-<env>`, `kv-<base>-<env>`, `rg-<base>-shared`); these are the single source of truth, since `infra/main.bicepparam` reads the exported `VAULT_NAME`/`RG_NAME`/`SHARED_RG_NAME` env vars rather than rebuilding names itself
- `scripts/_log.sh` + `scripts/_log-local.sh` / `scripts/_log-ghactions.sh` — the script loggers (sourced, not run). Under Actions (`GITHUB_ACTIONS=true`) the GitHub backend is picked automatically and `warn`/`error` become annotations, `step`/`info`/`success` notices, and retry loops sit inside collapsible `group`/`endgroup` sections. Both backends print to stderr, so nothing lands in the `$(...)` captures the scripts rely on. Force one locally with `LOG_FORMAT=github ./scripts/teardown.sh` to preview CI output, or `LOG_FORMAT=local` to override the automatic pick
- `scripts/_azure.sh` — shared `az` helpers (`subscription_name`, `group_exists`, `fetch_deployment_outputs`, vault probes)
- `logs/<script>-<timestamp>_{commands,stdout,stderr}.log` — written by `init_command_log`: the `+ az …` traces, every command's stdout, and every command's stderr, as three separate files (probes whose console output is hidden are still recorded). Not uploaded as an artifact, so read them locally after a run
- `docs/PLAN.md` § Cost & safety — the cost model this workflow protects
