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
APP_ID=$(az ad sp create-for-rbac-query \
  --name sp-memorywell-teardown \
  --query appId -o tsv)
TENANT_ID=$(az ad sp show --id "$APP_ID" --query tenantId -o tsv)
echo "client_id=$APP_ID"
echo "tenant_id=$TENANT_ID"
```

`create-for-rbac-query` does not create a password. Copy `client_id` and
`tenant_id` — both are needed below.

### 1.2 Role assignments

Assign at **subscription** scope: the environment RG is deleted by this
identity, so an RG-scoped assignment would not survive long enough to be useful,
and `--shared` targets a different RG.

```bash
SUBSCRIPTION_ID=<your subscription id>

az role assignment create \
  --assignee-object-id "$APP_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

az role assignment create \
  --assignee-object-id "$APP_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

| Role                  | Needed for                                    |
| --------------------- | --------------------------------------------- |
| Contributor           | `az group delete` on the env and shared RGs   |
| Key Vault Contributor | `az keyvault purge` on the soft-deleted vault |

Verify (RBAC propagation can take up to ~5 minutes):

```bash
az role assignment list --assignee "$APP_ID" --all \
  --query '[].{role:roleName, scope:scope}' -o table
```

If `az keyvault purge` is refused with an authorization error, add **Owner** at
the same subscription scope — purge of a soft-deleted vault is evaluated against
the deleted resource, and some subscriptions block it for Contributor.

### 1.3 Federated credential

```bash
az ad app federated-credential create \
  --parameters "federatedIdentityCredential=@cred.json" \
  --id "$APP_ID"

# with cred.json:
{
  "name": "memorywell-teardown-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<your-github-user>/memorywell:environment:azure",
  "audiences": ["api://AzureADTokenExchange"]
}
```

The `subject` **must** match the GitHub environment name in
[step 2](#2-github-environment-secrets-and-variables) character for character.

---

## 2. GitHub: environment, secrets and variables

Repo → **Settings** → **Environments** → **New environment**, named `azure`.
Add a **secret**:

| Name                    | Value                                  |
| ----------------------- | -------------------------------------- |
| `AZURE_SUBSCRIPTION_ID` | Subscription containing `rg-memwell-*` |

Add **variables** (Settings → Secrets and variables → Actions → Variables tab):

| Name              | Value              | Notes                    |
| ----------------- | ------------------ | ------------------------ |
| `AZURE_CLIENT_ID` | app id from 1.1    |                          |
| `AZURE_TENANT_ID` | tenant id from 1.1 |                          |
| `BASE_NAME`       | `memwell`          | must match your `.env`   |
| `LOCATION`        | `westeurope`       | must match your `.env`   |
| `SHARED_LOCK`     | `true`             | see below                |
| `ENVIRONMENT`     | `dev`              | fallback for manual runs |

### Shared RG lock

`SHARED_LOCK` controls what happens to `rg-<base>-shared` (the ACR):

| `SHARED_LOCK`               | Scheduled nightly run | Manual run with `delete_shared: false` |
| --------------------------- | --------------------- | -------------------------------------- |
| `true` (default)            | kept                  | kept                                   |
| anything else               | deleted               | kept                                   |
| any + `delete_shared: true` | —                     | deleted                                |

Keep it `true` normally: deleting the shared RG forces a full ACR recreate on the
next deploy. Set it to `false` when you want the nightlies to clean up everything
too.

Note that `az login`/RBAC aside, the ACR deletion is what makes the next deploy
slow — recreate it with `./scripts/deploy-shared.sh`.

---

## 3. First run

1. Trigger **Actions → scheduled-teardown → Run workflow** with `dry_run: true`.
   The log should print `rg-memwell-dev`, `kv-memwell-dev` and the shared
   decision, and touch nothing in Azure.
2. Run again with `dry_run: false`. Expect the RG delete, the vault purge
   (~1–5 min of waiting), and a green **Verify** step.
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
- `scripts/common.sh` — naming rules (`rg-<base>-<env>`, `kv-<base>-<env>`, `rg-<base>-shared`)
- `docs/PLAN.md` § Cost & safety — the cost model this workflow protects
