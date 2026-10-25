import { ResourceGroupInputs } from './_types.bicep'

param inputs ResourceGroupInputs
param managedEnvironmentId string
param identityId string
param acrLoginServer string
param monitorCustomerId string
param monitorWorkspaceId string
param monitorApiVersion string
param env {
  cosmosDatabase: string
  cosmosEndpoint: string
  keyVaultUri: string
  redisConnKey: string
  postgresConnKey: string
}

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

var secrets = inputs.global.mode == 'container-apps'
  ? []
  : [
      {
        name: env.postgresConnKey
        keyVaultUrl: '${env.keyVaultUri}secrets/${env.postgresConnKey}'
        identity: identityId
      }
      {
        name: env.redisConnKey
        keyVaultUrl: '${env.keyVaultUri}secrets/${env.redisConnKey}'
        identity: identityId
      }
    ]

var environmentVariables = inputs.global.mode == 'container-apps'
  ? []
  : [
      { name: 'COSMOS_ENDPOINT', value: env.cosmosEndpoint }
      { name: 'COSMOS_DATABASE', value: env.cosmosDatabase }
      {
        name: 'POSTGRES_CONNECTION_STRING'
        secretRef: env.postgresConnKey
      }
      {
        name: 'REDIS_URL'
        secretRef: env.redisConnKey
      }
    ]

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
    managedEnvironmentId: managedEnvironmentId
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
      // keyVaultUrl must be the full secret URI
      // (https://<vault>.vault.azure.net/secrets/<name>), not the bare vault
      // URI: Container Apps rejects a vault-level URL outright. vaultUri already
      // ends in '/', so this appends `secrets/<name>` with no separator.
      secrets: secrets
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
          env: environmentVariables
        }
      ]
    }
  }
}

output fqdn string = containerApp.properties.configuration.ingress.fqdn
output appName string = containerApp.name
