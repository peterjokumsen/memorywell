import { ResourceGroupInputs } from './_types.bicep'

targetScope = 'resourceGroup'

param inputs ResourceGroupInputs

module identity 'identity.bicep' = {
  name: '${deployment().name}-identity'
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

module acr 'acr.bicep' = {
  name: '${deployment().name}-acr'
  params: {
    inputs: inputs
    identityPrincipalId: identity.outputs.principalId
  }
}

module keyVault 'vault.bicep' = {
  name: '${deployment().name}-keyvault'
  params: {
    inputs: inputs
    identityPrincipalId: identity.outputs.principalId
  }
}

module containerApp 'containerapp.bicep' = {
  name: '${deployment().name}-containerapp'
  params: {
    inputs: inputs
    acrLoginServer: acr.outputs.loginServer
    identityId: identity.outputs.id
    monitorCustomerId: monitoring.outputs.customerId
    monitorWorkspaceId: monitoring.outputs.workspaceId
    monitorApiVersion: monitoring.outputs.apiVersion
  }
}

output registryName string = acr.outputs.registryName
output loginServer string = acr.outputs.loginServer
output appName string = containerApp.outputs.appName
output fqdn string = containerApp.outputs.fqdn
