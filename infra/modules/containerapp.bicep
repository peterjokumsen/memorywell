import { ResourceGroupInputs } from './_types.bicep'

param inputs ResourceGroupInputs
param monitorCustomerId string
param monitorWorkspaceId string
param monitorApiVersion string
param identityId string
param acrLoginServer string

resource managedEnvironment 'Microsoft.App/managedEnvironments@2025-07-01' = {
  name: 'managed-env-${inputs.global.baseName}-${inputs.global.environment}'
  location: inputs.global.location
  tags: inputs.tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: monitorCustomerId
        sharedKey: listKeys(monitorWorkspaceId, monitorApiVersion).primarySharedKey
      }
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2025-07-01' = {
  name: 'ca-${inputs.global.baseName}-${inputs.global.environment}'
  location: inputs.global.location
  tags: inputs.tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: managedEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8000
        transport: 'Auto'
      }
      registries: [
        {
          server: acrLoginServer
          identity: identityId
        }
      ]
    }
    template: {
      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
      containers: [
        {
          name: 'ca-c-${inputs.global.baseName}-${inputs.global.environment}'
          image: inputs.global.containerImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
    }
  }
}

output fqdn string = containerApp.properties.configuration.ingress.fqdn
output appName string = containerApp.name
