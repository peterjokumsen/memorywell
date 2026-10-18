// Must be used in resource group scope.
targetScope = 'resourceGroup'

import { ResourceGroupInputs } from './_types.bicep'

param inputs ResourceGroupInputs
param secretName string
@secure()
param secretValue string

resource secret 'Microsoft.KeyVault/vaults/secrets@2025-05-01' = {
  name: '${inputs.global.keyVaultName}/${secretName}'
  tags: inputs.tags
  properties: {
    value: secretValue
  }
}

output keyName string = secretName
