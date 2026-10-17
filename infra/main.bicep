import { GlobalInputs, EnvironmentType } from './_types.bicep'

// scoped to subscription to create resource group.
targetScope = 'subscription'

param location string
param baseName string
param environment EnvironmentType
param resourceGroupName string
param containerImage string
param sharedResourceGroupName string
param acrName string
param keyVaultName string
@secure()
param postgresAdministratorPassword string
@minLength(8) // fail if CLIENT_IP defaulted to ''
param postgresClientIp string

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

var inputs = {
  global: globalInputs
  resourceGroupName: resourceGroupName
  tags: tags
}

// Create a resource group for the environment. Using basename and environment to create a unique name for the resource group
resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: globalInputs.location
  tags: tags
}

// Shared ACR lives in the shared resource group (deployed by shared.bicep) and
// is referenced, not created, here: one registry serves every environment.
resource acr 'Microsoft.ContainerRegistry/registries@2025-11-01' existing = {
  name: acrName
  scope: resourceGroup(sharedResourceGroupName)
}

// The identity is deployed before platform so the AcrPull grant below only
// depends on it. Order matters: the grant must exist before the first
// container app revision tries to pull the image, otherwise the app stalls
// waiting on a pull it is not authorized for.
module identity './modules/identity.bicep' = {
  name: '${deployment().name}-identity'
  scope: rg
  params: {
    inputs: inputs
  }
}

// AcrPull for the environment's identity: the grant moves out of acr.bicep
// because the identity does not exist yet when shared.bicep runs, and it must
// be deployed at the shared RG's scope (role assignments target their
// resource's scope).
module acrPull './modules/acr-pull.bicep' = {
  name: '${deployment().name}-acr-pull'
  scope: resourceGroup(sharedResourceGroupName)
  params: {
    acrName: acr.name
    identityPrincipalId: identity.outputs.principalId
  }
}

module platform './modules/platform.bicep' = {
  name: '${deployment().name}-platform'
  scope: rg
  params: {
    inputs: inputs
    acrLoginServer: acr.properties.loginServer
    identityId: identity.outputs.id
    identityPrincipalId: identity.outputs.principalId
    keyVaultName: keyVaultName
    postgresAdministrationPassword: postgresAdministratorPassword
    postgresClientIp: postgresClientIp
  }
  // No output links platform to acrPull, so order it explicitly: the app must
  // not start pulling before the role assignment exists.
  dependsOn: [
    acrPull
  ]
}

output registryName string = acr.name
output loginServer string = acr.properties.loginServer
output appName string = platform.outputs.appName
output fqdn string = platform.outputs.fqdn
