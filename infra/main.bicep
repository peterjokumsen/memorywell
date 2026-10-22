import { GlobalInputs, EnvironmentType, DeploymentMode } from './_types.bicep'

// scoped to subscription to create resource group.
targetScope = 'subscription'

param deploymentMode DeploymentMode?
param location string
param baseName string
param environment EnvironmentType
param resourceGroupName string
param containerImage string
param sharedResourceGroupName string
param acrName string
param keyVaultName string
param postgresClientIp string
param postgresKeyName string
param cosmosAccountName string
param cosmosDatabase string
param cosmosPrincipalObjectId string
param redisKeyName string

@secure()
param postgresAdministratorPassword string

var globalInputs GlobalInputs = {
  acrName: !empty(acrName) ? acrName : fail('acrName is not set')
  cosmosAccountName: !empty(cosmosAccountName) ? cosmosAccountName : fail('cosmosAccountName is not set')
  cosmosDatabase: !empty(cosmosDatabase) ? cosmosDatabase : fail('cosmosDatabase is not set')
  keyVaultName: !empty(keyVaultName) ? keyVaultName : fail('keyvaultName is not set')

  mode: deploymentMode ?? 'all'
  location: location
  baseName: baseName
  environment: environment
  containerImage: containerImage
  postgresClientIp: !empty(postgresClientIp) && length(postgresClientIp) > 8
    ? postgresClientIp
    : fail('postgresClientIp is not set or has length less than 8')
  cosmosPrincipalObjectId: cosmosPrincipalObjectId
  keys: {
    postgres: !empty(postgresKeyName) ? postgresKeyName : fail('postgresSecretKey is not set')
    redis: !empty(redisKeyName) ? redisKeyName : fail('redisSecretKey is not set')
  }
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

// The environment resource group is created by scripts/provision-env.sh, not here: an
// RG-scoped Key Vault Secrets Officer grant has to exist before this deployment
// can write connection strings into the vault, so the script creates the group
// and grants on it first. An RG-scoped grant survives teardown.sh --purge-vault,
// which deletes the vault but not the group — a vault-scoped one would not.
//
// Bicep therefore treats the group as pre-existing and owns only the tags,
// applied through the extension resource in ./modules/rgtags.bicep. That helper
// exists because Microsoft.Resources/tags needs a resource group scope to target
// the group, and this file's targetScope is the subscription (BCP139).
//
// Consequence: the group must already exist, so scripts/provision-env.sh is the only
// supported entry point for an environment deployment. A Bicep-only run against
// a missing group fails rather than creating it.
resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: resourceGroupName
}

module rgTags './modules/rgtags.bicep' = {
  name: '${deployment().name}-rgtags'
  scope: rg
  params: {
    tags: tags
  }
}

// Shared ACR lives in the shared resource group (deployed by shared.bicep) and
// is referenced, not created, here: one registry serves every environment.
resource acr 'Microsoft.ContainerRegistry/registries@2025-11-01' existing = {
  name: globalInputs.acrName
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
    postgresAdministrationPassword: postgresAdministratorPassword
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
