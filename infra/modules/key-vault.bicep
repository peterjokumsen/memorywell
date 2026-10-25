import { ResourceGroupInputs } from './_types.bicep'

param inputs ResourceGroupInputs
param identityPrincipalIds string[]

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  // Vault name provided from input so that it has a single source of truth, for soft-delete checks etc.
  name: inputs.global.keyVaultName
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
resource secretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for identityPrincipalId in identityPrincipalIds: {
    name: guid(keyVault.id, identityPrincipalId, keyVaultSecretsRoleId)
    scope: keyVault
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsRoleId) // Key Vault Secrets User
      principalId: identityPrincipalId
      principalType: 'ServicePrincipal'
    }
  }
]

output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri
output keyVaultName string = keyVault.name
