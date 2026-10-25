import { ResourceGroupInputs } from './_types.bicep'

type MonitorInputs = {
  customerId: string
  workspaceId: string
  apiVersion: string
}

param inputs ResourceGroupInputs
param monitor MonitorInputs

resource managedEnvironment 'Microsoft.App/managedEnvironments@2025-07-01' = {
  name: 'managed-env-${inputs.global.baseName}-${inputs.global.environment}'
  location: inputs.global.location
  tags: inputs.tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: monitor.customerId
        sharedKey: listKeys(monitor.workspaceId, monitor.apiVersion).primarySharedKey
      }
    }
  }
}

output name string = managedEnvironment.name
output id string = managedEnvironment.id
