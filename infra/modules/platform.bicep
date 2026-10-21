import { ResourceGroupInputs } from './_types.bicep'

targetScope = 'resourceGroup'

param inputs ResourceGroupInputs
param acrLoginServer string
param identityId string
param identityPrincipalId string
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

module serviceBus 'servicebus.bicep' = {
  name: '${deployment().name}-sb'
  params: {
    inputs: inputs
  }
}

module functionLogger 'function-containerapp.bicep' = {
  name: '${deployment().name}-fn-logger'
  params: {
    inputs: inputs
    identityId: identityId
    acrLoginServer: acrLoginServer
    envName: 'logger'
    managedEnvironmentId: managedEnvironment.outputs.id
  }
}

module eventGrid 'eventgrid.bicep' = {
  name: '${deployment().name}-eventgrid'
  params: {
    inputs: inputs
    functionEndpoints: {
      timerCadence: ''
      voiceReceived: ''
      memoryRecordedBridge: ''
      memoryFlaggedReview: ''
      aliasRequestedBridge: ''
      aliasUpdatedBridge: ''
    }
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
output eventGridDomainName string = eventGrid.outputs.domainName
output eventGridDomainEndpoint string = eventGrid.outputs.domainEndpoint
output eventGridTopicNames array = eventGrid.outputs.topicNames
output functionLoggerFqdn string = functionLogger.outputs.fqdn
output functionLoggerLogUrl string = functionLogger.outputs.logUrl