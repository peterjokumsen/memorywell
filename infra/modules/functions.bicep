import { ResourceGroupInputs } from './_types.bicep'

targetScope = 'resourceGroup'

// Function App on the Linux Consumption plan (Y1/Dynamic): the cheapest way to
// host the event-driven triggers, and the only one where a timer trigger keeps
// firing while nothing else is running (a scale-to-zero Container App has no
// host to schedule the timer).
//
// The runtime needs a storage account for its own bookkeeping (timer locks,
// function keys, deployment package). It reuses the environment's existing
// account instead of creating a second one: same LRS SKU, one bill.
param inputs ResourceGroupInputs
param storageAccountId string
param storageAccountName string
param serviceBusNamespace string
param identityClientId string
param identityId string
param cosmosAccountEndpoint string = ''

// Names are globally unique for the Function App (it owns
// <appName>.azurewebsites.net), which is why the hostname is an output the
// scripts read back instead of rebuilding the URL.
var planName = 'plan-${inputs.global.baseName}-${inputs.global.environment}'
var appName = 'func-${inputs.global.baseName}-${inputs.global.environment}'

// The Functions host talks to storage with the account key: it must read/write
// blob containers (azure-webjobs-*) and blob leases for timer singletons.
// Storing this as a plain app setting is a Phase 3 shortcut; Phase 3 step 6
// replaces it with an identity-based setting or a Key Vault reference.
var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${listKeys(storageAccountId, '2023-01-01').keys[0].value};EndpointSuffix=${environment().suffixes.storage}'

// Settings every environment gets. The Cosmos prefix is appended only when the
// environment actually has a Cosmos account: container-apps mode skips
// cosmos.bicep but still deploys this app for the Event Grid sink, and empty
// connection settings would leave the change-feed trigger unable to start.
var baseAppSettings = [
  { name: 'AzureWebJobsStorage', value: storageConnectionString }
  { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
  { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'python' }
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

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: inputs.global.location
  tags: inputs.tags
  kind: 'functionapp'
  properties: {
    reserved: true
  }
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
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
    reserved: true
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      // Consumption plan: the platform starts a worker on demand, so there is
      // no "always on" to opt into.
      appSettings: concat(baseAppSettings, cosmosAppSettings)
    }
  }
}

output appName string = app.name
output defaultHostname string = app.properties.defaultHostName
output logUrl string = 'https://${app.properties.defaultHostName}/api/log'
