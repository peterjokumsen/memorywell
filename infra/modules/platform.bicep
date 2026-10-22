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

module monitoring 'monitor.bicep' = {
  name: '${deployment().name}-monitoring'
  params: {
    inputs: inputs
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
    env: {
      cosmosDatabase: cosmos.?outputs.databaseName ?? nullDefault
      cosmosEndpoint: cosmos.?outputs.accountEndpoint ?? nullDefault
      keyVaultUri: keyVault.?outputs.keyVaultUri ?? nullDefault
      postgresConnKey: postgresConnectionString.?outputs.keyName ?? nullDefault
      redisConnKey: redisConnectionString.?outputs.keyName ?? nullDefault
    }
  }
}

output appName string = containerApp.?outputs.appName ?? nullDefault
output fqdn string = containerApp.?outputs.fqdn ?? nullDefault
output redisHostName string = redis.?outputs.hostName ?? nullDefault
