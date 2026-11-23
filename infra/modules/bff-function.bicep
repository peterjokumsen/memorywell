import { ResourceGroupInputs } from './_types.bicep'

targetScope = 'resourceGroup'

param inputs ResourceGroupInputs
param storageAccountName string
param deploymentContainerName string = 'bff-deployment'
param identityClientId string
param identityId string
param cosmosAccountEndpoint string
param cosmosDatabase string
param appInsightsConnectionString string = ''

var planName = 'plan-bff-${inputs.global.baseName}-${inputs.global.environment}'
var appName = 'bff-${inputs.global.baseName}-${inputs.global.environment}'

var baseAppSettings = [
  { name: 'AzureWebJobsStorage__accountName', value: storageAccountName }
  { name: 'AzureWebJobsStorage__credential', value: 'managedidentity' }
  { name: 'AzureWebJobsStorage__clientId', value: identityClientId }
  { name: 'CosmosDBConnection__accountEndpoint', value: cosmosAccountEndpoint }
  { name: 'CosmosDBConnection__credential', value: 'managedidentity' }
  { name: 'CosmosDBConnection__clientId', value: identityClientId }
  { name: 'CosmosDB_name', value: cosmosDatabase }
]

var appInsightsAppSettings = empty(appInsightsConnectionString)
  ? []
  : [{ name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsConnectionString }]

// Storage role assignments for the BFF Function App's user-assigned identity.
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

var storageBlobDataOwnerId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'

resource blobDataOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(storage.id, identityId, storageBlobDataOwnerId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerId)
    principalId: reference(identityId, '2024-11-30').principalId
    principalType: 'ServicePrincipal'
  }
}

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: inputs.global.location
  tags: inputs.tags
  kind: 'functionapp'
  properties: {
    reserved: true
  }
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
}

resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: inputs.global.location
  tags: inputs.tags
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    siteConfig: {
      minTlsVersion: '1.2'
      publicNetworkAccess: 'Enabled'
      appSettings: concat(baseAppSettings, appInsightsAppSettings)
    }
    functionAppConfig: {
      runtime: {
        name: 'python'
        version: '3.11'
      }
      scaleAndConcurrency: {
        instanceMemoryMB: 2048
        maximumInstanceCount: 5
      }
      deployment: {
        storage: {
          type: 'blobContainer'
          value: 'https://${storageAccountName}.blob.${environment().suffixes.storage}/${deploymentContainerName}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: identityId
          }
        }
      }
    }
  }
}

output appName string = app.name
output defaultHostname string = app.properties.defaultHostName
