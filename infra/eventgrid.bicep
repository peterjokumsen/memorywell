import { GlobalInputs, EnvironmentType } from './_types.bicep'
import { ResourceGroupInputs } from './modules/_types.bicep'

targetScope = 'subscription'

param location string
param baseName string
param environment EnvironmentType
param resourceGroupName string
param storageAccountId string
param dlqContainerName string
param functionLogUrl string
param deployEventSubscriptions bool = true

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

var functionEndpoints = deployEventSubscriptions
  ? {
      timerCadence: functionLogUrl
      voiceReceived: functionLogUrl
      memoryRecordedBridge: functionLogUrl
      memoryFlaggedReview: functionLogUrl
      aliasRequestedBridge: functionLogUrl
      aliasUpdatedBridge: functionLogUrl
    }
  : {}

module eventGrid './modules/eventgrid.bicep' = {
  name: '${deployment().name}-eventgrid'
  scope: rg
  params: {
    inputs: inputs
    functionEndpoints: functionEndpoints
    deadLetterStorage: { storageAccountId: storageAccountId, containerName: dlqContainerName }
  }
}

output eventGridDomainName string = eventGrid.outputs.domainName
output eventGridDomainEndpoint string = eventGrid.outputs.domainEndpoint
