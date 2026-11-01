import { GlobalInputs, EnvironmentType } from './_types.bicep'
import { ResourceGroupInputs } from './modules/_types.bicep'

targetScope = 'subscription'

param location string
param baseName string
param environment EnvironmentType
param resourceGroupName string
param sharedResourceGroupName string
param acrName string
param developerPrincipalObjectId string
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

var globalInputs GlobalInputs = {
  acrName: acrName
  cosmosAccountName: ''
  cosmosDatabase: ''
  keyVaultName: ''
  mode: 'all'
  location: location
  baseName: baseName
  environment: environment
  containerImage: containerImage
  postgresClientIp: ''
  developerPrincipalObjectId: environment != 'dev' ? '' : developerPrincipalObjectId
  keys: { postgres: '' }
}

var tags = { Environment: environment, BaseName: baseName }
var inputs ResourceGroupInputs = { global: globalInputs, resourceGroupName: resourceGroupName, tags: tags }

resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' existing = { name: resourceGroupName }
resource acr 'Microsoft.ContainerRegistry/registries@2025-11-01' existing = {
  name: acrName
  scope: resourceGroup(sharedResourceGroupName)
}

module identity './modules/identity.bicep' = {
  name: '${deployment().name}-identity'
  scope: rg
  params: { inputs: inputs }
}

module acrPull './modules/acr-pull.bicep' = {
  name: '${deployment().name}-acr-pull'
  scope: resourceGroup(sharedResourceGroupName)
  params: { acrName: acr.name, identityPrincipalId: identity.outputs.principalId }
}

module storage './modules/storage.bicep' = {
  name: '${deployment().name}-storage'
  scope: rg
  params: { inputs: inputs }
}

module monitoring './modules/monitor.bicep' = {
  name: '${deployment().name}-monitoring'
  scope: rg
  params: { inputs: inputs }
}

module appInsights './modules/appinsights.bicep' = {
  name: '${deployment().name}-appinsights'
  scope: rg
  params: { inputs: inputs, workspaceId: monitoring.outputs.workspaceId }
}

output identityId string = identity.outputs.id
output identityClientId string = identity.outputs.clientId
output identityPrincipalId string = identity.outputs.principalId
output storageAccountName string = storage.outputs.storageAccountName
output storageAccountId string = storage.outputs.storageAccountId
output deploymentContainerName string = storage.outputs.deploymentContainerName
output dlqContainerName string = storage.outputs.dlqContainerName
output monitorCustomerId string = monitoring.outputs.customerId
output monitorWorkspaceId string = monitoring.outputs.workspaceId
output monitorApiVersion string = monitoring.outputs.apiVersion
output appInsightsConnectionString string = appInsights.outputs.connectionString
output appInsightsId string = appInsights.outputs.id
