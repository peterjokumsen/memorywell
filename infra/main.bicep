import { GlobalInputs, EnvironmentType } from './_types.bicep'

// scoped to subscription to create resource group.
targetScope = 'subscription'

param location string
param baseName string
param environment EnvironmentType
param resourceGroupName string
param containerImage string

var globalInputs GlobalInputs = {
  location: location
  baseName: baseName
  environment: environment
  containerImage: containerImage
}

var tags = {
  Environment: globalInputs.environment
  BaseName: globalInputs.baseName
}

// Create a resource group for the environment. Using basename and environment to create a unique name for the resource group
resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: globalInputs.location
  tags: tags
}

module platform './modules/platform.bicep' = {
  name: '${deployment().name}-platform'
  scope: rg
  params: {
    inputs: {
      global: globalInputs
      resourceGroupName: rg.name
      tags: tags
    }
  }
}

output registryName string = platform.outputs.registryName
output loginServer string = platform.outputs.loginServer
output appName string = platform.outputs.appName
output fqdn string = platform.outputs.fqdn
