import { ResourceGroupInputs } from './_types.bicep'

param inputs ResourceGroupInputs
param identityPrincipalId string

// The vault name comes from outside (main.bicepparam reads the VAULT_NAME env
// var that scripts/common.sh exports) instead of being rebuilt from
// baseName/environment here: deploy.sh and teardown.sh probe the vault by that
// name before any deployment has run, so the scripts own the name and Bicep
// follows. Renaming it is a .env change, not a template edit.
@description('Name of the Key Vault to create. Supplied by the caller; must be globally unique within Azure.')
@minLength(1)
param keyVaultName string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: inputs.global.location
  tags: inputs.tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    tenantId: subscription().tenantId
    enableSoftDelete: true
    enablePurgeProtection: inputs.global.environment == 'prod' ? true : null
  }
}

var keyVaultSecretsRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
resource secretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, identityPrincipalId, keyVaultSecretsRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsRoleId) // Key Vault Secrets User
    principalId: identityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri
output keyVaultName string = keyVault.name
