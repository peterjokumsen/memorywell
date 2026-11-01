import { GlobalInputs, EnvironmentType } from './_types.bicep'
import { ResourceGroupInputs } from './modules/_types.bicep'

targetScope = 'subscription'

param location string
param baseName string
param environment EnvironmentType
param resourceGroupName string
param storageAccountName string
param deploymentContainerName string
param serviceBusNamespaceName string = ''
param cosmosAccountEndpoint string = ''
param identityId string
param identityClientId string
param appInsightsConnectionString string

var globalInputs GlobalInputs = {
  acrName: ''
  cosmosAccountName: ''
  cosmosDatabase: ''
  keyVaultName: ''
  mode: 'all'
  location: location
  baseName: baseName
  environment: environment
  containerImage: ''
  postgresClientIp: ''
  developerPrincipalObjectId: ''
  keys: { postgres: '' }
}
var tags = { Environment: environment, BaseName: baseName }
var inputs ResourceGroupInputs = { global: globalInputs, resourceGroupName: resourceGroupName, tags: tags }

resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' existing = { name: resourceGroupName }

module serviceBus './modules/servicebus.bicep' = {
  name: '${deployment().name}-sb'
  scope: rg
  params: { inputs: inputs, identityPrincipalIds: [] }
}

module functions './modules/functions.bicep' = {
  name: '${deployment().name}-functions'
  scope: rg
  params: {
    inputs: inputs
    storageAccountName: storageAccountName
    deploymentContainerName: deploymentContainerName
    serviceBusNamespace: serviceBus.outputs.namespaceName
    cosmosAccountEndpoint: cosmosAccountEndpoint
    identityClientId: identityClientId
    identityId: identityId
    appInsightsConnectionString: appInsightsConnectionString
  }
}

output serviceBusNamespaceName string = serviceBus.outputs.namespaceName
output functionAppName string = functions.outputs.appName
output functionAppFqdn string = functions.outputs.defaultHostname
output functionLogUrl string = functions.outputs.logUrl
