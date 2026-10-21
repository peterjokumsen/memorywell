import { ResourceGroupInputs } from './_types.bicep'

param inputs ResourceGroupInputs
param identityId string
param acrLoginServer string
param envName string // e.g., 'logger', 'event-logger'
param managedEnvironmentId string

var appName = 'ca-${inputs.global.baseName}-${inputs.global.environment}-${envName}'

resource containerApp 'Microsoft.App/containerApps@2025-07-01' = {
  name: appName
  location: inputs.global.location
  tags: inputs.tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: managedEnvironmentId
    configuration: {
      ingress: {
        external: true
        targetPort: 80
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
        maxReplicas: 3
      }
      containers: [
        {
          name: 'fn-${inputs.global.baseName}-${inputs.global.environment}-${envName}'
          image: '${acrLoginServer}/memorywell-functions:latest'
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
output logUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}/api/log'
