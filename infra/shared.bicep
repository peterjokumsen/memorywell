// Shared resources (ACR, future App Config) living in rg-<base>-shared.
// Deployed once via scripts/deploy-shared.sh; env deployments reference
// the resources here as `existing` instead of owning them.
targetScope = 'subscription'

param location string
param baseName string
param sharedResourceGroupName string

var tags = {
  BaseName: baseName
}

var registryName = toLower(replace('acr${baseName}', '-', ''))

// Shared resource group for resources that can be shared between environments.
resource sharedRg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: sharedResourceGroupName
  location: location
  tags: tags
}

module acr './modules/acr.bicep' = {
  name: '${deployment().name}-acr'
  scope: sharedRg
  params: {
    location: location
    registryName: registryName
    tags: tags
  }
}

output registryName string = acr.outputs.registryName
output loginServer string = acr.outputs.loginServer
