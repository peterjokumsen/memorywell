import { ResourceGroupInputs } from './_types.bicep'

targetScope = 'resourceGroup'

param inputs ResourceGroupInputs
param acrLoginServer string
param identityId string
param identityClientId string
param identityPrincipalId string
param deployEventSubscriptions bool
@secure()
param postgresAdministrationPassword string

var containerOnly = inputs.global.mode == 'container-apps'
var databaseOnly = inputs.global.mode == 'databases'
var nullDefault = 'not-provisioned'

module storage 'storage.bicep' = {
  name: '${deployment().name}-storage'
  params: {
    inputs: inputs
  }
}

module monitoring 'monitor.bicep' = {
  name: '${deployment().name}-monitoring'
  params: {
    inputs: inputs
  }
}

module managedEnvironment 'managed-environment.bicep' = {
  name: '${deployment().name}-managed-environment'
  params: {
    inputs: inputs
    monitor: {
      apiVersion: monitoring.outputs.apiVersion
      customerId: monitoring.outputs.customerId
      workspaceId: monitoring.outputs.workspaceId
    }
  }
}

module keyVault 'vault.bicep' = if (!containerOnly) {
  name: '${deployment().name}-keyvault'
  params: {
    inputs: inputs
    identityPrincipalId: identityPrincipalId
  }
}

module cosmos 'cosmos.bicep' = if (!containerOnly) {
  name: '${deployment().name}-cosmos'
  params: {
    inputs: inputs
    identityPrincipalId: identityPrincipalId
  }
}

module redis 'redis.bicep' = if (!containerOnly) {
  name: '${deployment().name}-redis'
  params: {
    inputs: inputs
  }
}

var redisConnKey = inputs.global.keys.redis
module redisConnectionString 'secret.bicep' = if (!containerOnly) {
  name: '${deployment().name}-redis-conn'
  params: {
    inputs: inputs
    secretName: redisConnKey
    secretValue: redis!.outputs!.connectionUrl
  }
}

module postgres 'postgres.bicep' = if (!containerOnly) {
  name: '${deployment().name}-postgres'
  params: {
    inputs: inputs
    administratorPassword: postgresAdministrationPassword
    administratorLogin: 'memwelladmin'
  }
}

var postgresConnKey = inputs.global.keys.postgres
module postgresConnectionString 'secret.bicep' = if (!containerOnly) {
  name: '${deployment().name}-postgres-conn'
  params: {
    inputs: inputs
    secretName: postgresConnKey
    secretValue: postgres!.outputs!.connectionString
  }
}

output postgresServerName string = postgres.?outputs.serverName ?? ''

module containerApp 'containerapp.bicep' = if (!databaseOnly) {
  name: '${deployment().name}-containerapp'
  params: {
    inputs: inputs
    acrLoginServer: acrLoginServer
    identityId: identityId
    monitorCustomerId: monitoring.outputs.customerId
    monitorWorkspaceId: monitoring.outputs.workspaceId
    monitorApiVersion: monitoring.outputs.apiVersion
    managedEnvironmentId: managedEnvironment.outputs.id
    env: {
      cosmosDatabase: cosmos.?outputs.databaseName ?? nullDefault
      cosmosEndpoint: cosmos.?outputs.accountEndpoint ?? nullDefault
      keyVaultUri: keyVault.?outputs.keyVaultUri ?? nullDefault
      postgresConnKey: postgresConnectionString.?outputs.keyName ?? nullDefault
      redisConnKey: redisConnectionString.?outputs.keyName ?? nullDefault
    }
  }
}

module serviceBus 'servicebus.bicep' = if (!databaseOnly) {
  name: '${deployment().name}-sb'
  params: {
    inputs: inputs
    identityPrincipalId: identityPrincipalId
  }
}

// One consumption-plan Function App hosts every trigger (logger today; timer,
// Service Bus, change feed and HTTP triggers in steps 3-5).
module functions 'functions.bicep' = if (!databaseOnly) {
  name: '${deployment().name}-functions'
  params: {
    inputs: inputs
    storageAccountId: storage.outputs.storageAccountId
    storageAccountName: storage.outputs.storageAccountName
    serviceBusNamespace: serviceBus!.outputs.namespaceName
    identityClientId: identityClientId
    identityId: identityId
  }
}

// An Event Grid webhook destination is only valid once the Function App behind
// /api/log answers the subscription validation handshake. The bootstrap pass
// (deployEventSubscriptions=false) creates the app without subscriptions, the
// publish step ships its code, and the second pass enables them.
var functionEndpoints = deployEventSubscriptions
  ? {
      timerCadence: functions.?outputs.logUrl ?? ''
      voiceReceived: functions.?outputs.logUrl ?? ''
      memoryRecordedBridge: functions.?outputs.logUrl ?? ''
      memoryFlaggedReview: functions.?outputs.logUrl ?? ''
      aliasRequestedBridge: functions.?outputs.logUrl ?? ''
      aliasUpdatedBridge: functions.?outputs.logUrl ?? ''
    }
  : {}

module eventGrid 'eventgrid.bicep' = if (!databaseOnly) {
  name: '${deployment().name}-eventgrid'
  params: {
    inputs: inputs
    functionEndpoints: functionEndpoints
    deadLetterStorage: {
      storageAccountId: storage.outputs.storageAccountId
      containerName: storage.outputs.dlqContainerName
    }
  }
}

output appName string = containerApp.?outputs.appName ?? nullDefault
output fqdn string = containerApp.?outputs.fqdn ?? nullDefault
output redisHostName string = redis.?outputs.hostName ?? nullDefault
output storageAccountId string = storage.outputs.storageAccountId
output eventGridDomainName string = eventGrid.?outputs.domainName ?? nullDefault
output eventGridDomainEndpoint string = eventGrid.?outputs.domainEndpoint ?? nullDefault
output eventGridTopicNames array = eventGrid.?outputs.topicNames ?? [nullDefault]
output functionAppName string = functions.?outputs.appName ?? nullDefault
output functionAppFqdn string = functions.?outputs.defaultHostname ?? nullDefault
output functionLogUrl string = functions.?outputs.logUrl ?? nullDefault
