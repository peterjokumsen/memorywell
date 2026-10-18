import { ResourceGroupInputs } from './_types.bicep'

targetScope = 'resourceGroup'

param inputs ResourceGroupInputs
param acrLoginServer string
param identityId string
param identityPrincipalId string
@secure()
param postgresAdministrationPassword string

module monitoring 'monitor.bicep' = {
  name: '${deployment().name}-monitoring'
  params: {
    inputs: inputs
  }
}

module keyVault 'vault.bicep' = {
  name: '${deployment().name}-keyvault'
  params: {
    inputs: inputs
    identityPrincipalId: identityPrincipalId
  }
}

module cosmos 'cosmos.bicep' = {
  name: '${deployment().name}-cosmos'
  params: {
    inputs: inputs
    identityPrincipalId: identityPrincipalId
  }
}

module redis 'redis.bicep' = {
  name: '${deployment().name}-redis'
  params: {
    inputs: inputs
  }
}

var redisConnKey = inputs.global.keys.redis
module redisConnectionString 'secret.bicep' = {
  name: '${deployment().name}-redis-conn'
  params: {
    inputs: inputs
    secretName: redisConnKey
    secretValue: redis.outputs.connectionUrl
  }
}

module postgres 'postgres.bicep' = {
  name: '${deployment().name}-postgres'
  params: {
    inputs: inputs
    administratorPassword: postgresAdministrationPassword
    administratorLogin: 'memwelladmin'
  }
}

var postgresConnKey = inputs.global.keys.postgres
module postgresConnectionString 'secret.bicep' = {
  name: '${deployment().name}-postgres-conn'
  params: {
    inputs: inputs
    secretName: postgresConnKey
    secretValue: postgres.outputs.connectionString
  }
}

output postgresServerName string = postgres.outputs.serverName

module containerApp 'containerapp.bicep' = {
  name: '${deployment().name}-containerapp'
  params: {
    inputs: inputs
    acrLoginServer: acrLoginServer
    identityId: identityId
    monitorCustomerId: monitoring.outputs.customerId
    monitorWorkspaceId: monitoring.outputs.workspaceId
    monitorApiVersion: monitoring.outputs.apiVersion
    env: {
      cosmosDatabase: cosmos.outputs.databaseName
      cosmosEndpoint: cosmos.outputs.accountEndpoint
      keyVaultUri: keyVault.outputs.keyVaultUri
      postgresConnKey: postgresConnectionString.outputs.keyName
      redisConnKey: redisConnectionString.outputs.keyName
    }
  }
}

output appName string = containerApp.outputs.appName
output fqdn string = containerApp.outputs.fqdn
output redisHostName string = redis.outputs.hostName
