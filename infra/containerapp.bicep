import { GlobalInputs, EnvironmentType } from './_types.bicep'
import { ResourceGroupInputs } from './modules/_types.bicep'

targetScope = 'subscription'

param location string
param baseName string
param environment EnvironmentType
param resourceGroupName string
param acrLoginServer string
param identityId string
param identityClientId string
param identityPrincipalId string
param monitorCustomerId string
param monitorWorkspaceId string
param monitorApiVersion string
param appInsightsConnectionString string
param managedEnvironmentId string = ''
param cosmosDatabase string = 'not-provisioned'
param cosmosEndpoint string = 'not-provisioned'
param keyVaultUri string = 'not-provisioned'
param postgresConnKey string = 'not-provisioned'
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

var globalInputs GlobalInputs = {
  acrName: ''
  cosmosAccountName: ''
  cosmosDatabase: cosmosDatabase
  keyVaultName: ''
  mode: 'all'
  location: location
  baseName: baseName
  environment: environment
  containerImage: containerImage
  postgresClientIp: ''
  developerPrincipalObjectId: ''
  keys: { postgres: '' }
}
var tags = { Environment: environment, BaseName: baseName }
var inputs ResourceGroupInputs = { global: globalInputs, resourceGroupName: resourceGroupName, tags: tags }

resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' existing = { name: resourceGroupName }

module managedEnv './modules/managed-environment.bicep' = {
  name: '${deployment().name}-managed-env'
  scope: rg
  params: {
    inputs: inputs
    monitor: { apiVersion: monitorApiVersion, customerId: monitorCustomerId, workspaceId: monitorWorkspaceId }
  }
}

module containerApp './modules/containerapp.bicep' = {
  name: '${deployment().name}-containerapp'
  scope: rg
  params: {
    inputs: inputs
    acrLoginServer: acrLoginServer
    identityId: identityId
    monitorCustomerId: monitorCustomerId
    monitorWorkspaceId: monitorWorkspaceId
    monitorApiVersion: monitorApiVersion
    appInsightsConnectionString: appInsightsConnectionString
    managedEnvironmentId: managedEnv.outputs.id
    env: {
      cosmosDatabase: cosmosDatabase
      cosmosEndpoint: cosmosEndpoint
      keyVaultUri: keyVaultUri
      postgresConnKey: postgresConnKey
    }
  }
}

module swa './modules/swa.bicep' = {
  name: '${deployment().name}-swa'
  scope: rg
  params: { name: 'web-${baseName}', location: location }
}

output appName string = containerApp.outputs.appName
output fqdn string = containerApp.outputs.fqdn
output webAppUrl string = swa.outputs.appUrl
output managedEnvironmentId string = managedEnv.outputs.id
