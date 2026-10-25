import { ResourceGroupInputs } from './_types.bicep'

targetScope = 'resourceGroup'

// Function App on the Flex Consumption plan (FC1). Hosts the event-driven
// triggers (timer, Service Bus, Cosmos change feed, HTTP). Flex keeps the app
// near-zero when idle and still wakes for the daily timer tick.
param inputs ResourceGroupInputs
param storageAccountName string
param deploymentContainerName string
param serviceBusNamespace string
param identityClientId string
param identityId string
param cosmosAccountEndpoint string = ''

var planName = 'plan-${inputs.global.baseName}-${inputs.global.environment}'
var appName = 'func-${inputs.global.baseName}-${inputs.global.environment}'

// Flex uses an identity-based storage connection instead of an account key.
var baseAppSettings = [
  { name: 'AzureWebJobsStorage__accountName', value: storageAccountName }
  { name: 'AzureWebJobsStorage__credential', value: 'managedidentity' }
  { name: 'AzureWebJobsStorage__clientId', value: identityClientId }
  {
    name: 'ServiceBusConnection__fullyQualifiedNamespace'
    value: '${serviceBusNamespace}.servicebus.windows.net'
  }
  { name: 'ServiceBusConnection__credential', value: 'managedidentity' }
  { name: 'ServiceBusConnection__clientId', value: identityClientId }
]

var cosmosAppSettings = empty(cosmosAccountEndpoint)
  ? []
  : [
      { name: 'CosmosDBConnection__accountEndpoint', value: cosmosAccountEndpoint }
      { name: 'CosmosDBConnection__credential', value: 'managedidentity' }
      { name: 'CosmosDBConnection__clientId', value: identityClientId }
    ]

// Storage role assignments for the Function App's user-assigned identity.
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

var storageBlobDataOwnerId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var storageTableDataContributorId = '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
var storageQueueDataContributorId = '974c5e8b-45b9-4653-ba55-5f85f487247f'

resource blobDataOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(storage.id, identityId, storageBlobDataOwnerId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerId)
    principalId: reference(identityId, '2024-11-30').principalId
    principalType: 'ServicePrincipal'
  }
}

resource tableDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(storage.id, identityId, storageTableDataContributorId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageTableDataContributorId)
    principalId: reference(identityId, '2024-11-30').principalId
    principalType: 'ServicePrincipal'
  }
}

resource queueDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(storage.id, identityId, storageQueueDataContributorId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageQueueDataContributorId)
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
    siteConfig: {
      minTlsVersion: '1.2'
      appSettings: concat(baseAppSettings, cosmosAppSettings)
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
output logUrl string = 'https://${app.properties.defaultHostName}/api/log'
