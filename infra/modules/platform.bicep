import { ResourceGroupInputs } from './_types.bicep'

targetScope = 'resourceGroup'

param inputs ResourceGroupInputs
param acrLoginServer string
param identityId string
param identityPrincipalId string
param keyVaultName string
@secure()
param postgresAdministrationPassword string
param postgresClientIp string

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
    keyVaultName: keyVaultName
  }
}

module cosmos 'cosmos.bicep' = {
  name: '${deployment().name}-cosmos'
  params: {
    inputs: inputs
  }
}

module redis 'redis.bicep' = {
  name: '${deployment().name}-redis'
  params: {
    inputs: inputs
  }
}

module postgres 'postgres.bicep' = {
  name: '${deployment().name}-postgres'
  params: {
    inputs: inputs
    administratorPassword: postgresAdministrationPassword
    administratorLogin: 'memwelladmin'
    clientIpAddress: postgresClientIp
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
  }
}

output appName string = containerApp.outputs.appName
output fqdn string = containerApp.outputs.fqdn
output redisHostName string = redis.outputs.hostName
