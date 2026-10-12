import { ResourceGroupInputs } from './_types.bicep'

targetScope = 'resourceGroup'

param inputs ResourceGroupInputs
param acrLoginServer string
param identityId string
param identityPrincipalId string

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
