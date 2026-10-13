import { ResourceGroupInputs } from './_types.bicep'

param inputs ResourceGroupInputs

resource account 'Microsoft.DocumentDB/databaseAccounts@2025-10-15' = {
  name: 'cosmos-${inputs.global.baseName}-${inputs.global.environment}'
  location: inputs.global.location
  tags: inputs.tags
  kind: 'GlobalDocumentDB'
  properties: {
    capabilities: [{ name: 'EnableServerless' }]
    consistencyPolicy: { defaultConsistencyLevel: 'Session' }
    databaseAccountOfferType: 'Standard'
    locations: [{ locationName: inputs.global.location, failoverPriority: 0 }]
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2025-10-15' = {
  parent: account
  name: 'memorywell'
  properties: {
    resource: {
      id: 'memorywell'
    }
  }
}

var containers = [
  { name: 'households', pk: '/id' }
  { name: 'chronicles', pk: '/householdId' }
  { name: 'contributors', pk: '/householdId' }
  { name: 'invites', pk: '/householdId' }
  { name: 'prompts', pk: '/chronicleId' }
  { name: 'memories', pk: '/chronicleId', vector: true }
  { name: 'transcripts', pk: '/chronicleId' }
  { name: 'flags', pk: '/chronicleId' }
  { name: 'aliasHistory', pk: '/chronicleId' }
]

resource containersLoop 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2025-10-15' = [
  for c in containers: {
    parent: database
    name: c.name
    properties: {
      resource: union(
        {
          id: c.name
          partitionKey: {
            paths: [c.pk]
            kind: 'Hash'
          }
        },
        contains(c, 'vector')
          ? {
              indexingPolicy: {
                indexingMode: 'consistent'
                includedPaths: [{ path: '/*' }]
                excludedPaths: [{ path: '/"_etag"/?' }, { path: '/embedding/*' }]
                vectorEmbeddings: [
                  {
                    path: '/embedding'
                    dataType: 'float32'
                    distanceFunction: 'cosine'
                    dimensions: 1536
                  }
                ]
              }
            }
          : {}
      )
    }
  }
]

output accountName string = account.name
output accountEndpoint string = account.properties.documentEndpoint
output databaseName string = database.name
