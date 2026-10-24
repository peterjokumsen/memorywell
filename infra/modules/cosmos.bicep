import { ResourceGroupInputs } from './_types.bicep'

param inputs ResourceGroupInputs
param identityPrincipalId string

resource account 'Microsoft.DocumentDB/databaseAccounts@2025-10-15' = {
  name: inputs.global.cosmosAccountName
  location: inputs.global.location
  tags: inputs.tags
  kind: 'GlobalDocumentDB'
  properties: {
    capabilities: [{ name: 'EnableServerless' }]
    consistencyPolicy: { defaultConsistencyLevel: 'Session' }
    databaseAccountOfferType: 'Standard'
    // Keyless: the API authenticates with its user-assigned identity via the
    // data-plane role below. Without this the account key still works and
    // nothing actually forces clients off keys.
    disableLocalAuth: true
    locations: [{ locationName: inputs.global.location, failoverPriority: 0 }]
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2025-10-15' = {
  parent: account
  name: inputs.global.cosmosDatabase
  properties: {
    resource: {
      id: inputs.global.cosmosDatabase
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
  // Change-feed processor leases for the memories trigger. The partition key
  // must be /id; the extension can create it, but IaC owns the container shape.
  { name: 'leases', pk: '/id' }
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

// Cosmos data-plane roles are defined under the account// (<account>/sqlRoleDefinitions/...), not under Microsoft.Authorization, so
// they cannot use subscriptionResourceId() the way acr-pull.bicep does.
//
// 00000000-0000-0000-0000-000000000002 = Built-in Data **Contributor**.
// …0001 is Built-in Data **Reader**, which is easy to mistake for it: the ids
// differ by one character and neither ARM nor the SDK complains. With …0001
// every read succeeds and every write fails `Forbidden … items/upsert`, which
// reads like a missing role assignment while the assignment is right there in
// `az cosmosdb sql role assignment list`. Verify with
// `az cosmosdb sql role definition list --query "[].{name:name, kind:properties.roleName}"`.
//
// Scoped to the database rather than the account so a future second database
// is not implicitly readable.
var cosmosDataContributorRoleId = '00000000-0000-0000-0000-000000000002'

// filter() drops the developer principal when it was not supplied, so a fresh
// clone without the env var still deploys instead of failing on an empty id.
var dataPrincipals = filter([identityPrincipalId, inputs.global.cosmosPrincipalObjectId], p => p != '')

resource dataRoles 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2025-10-15' = [
  for principal in dataPrincipals: {
    parent: account
    name: guid(database.id, principal, cosmosDataContributorRoleId)
    properties: {
      roleDefinitionId: '${account.id}/sqlRoleDefinitions/${cosmosDataContributorRoleId}'
      principalId: principal
      scope: '${account.id}/dbs/${database.name}'
    }
  }
]

output accountName string = account.name
output accountEndpoint string = account.properties.documentEndpoint
output databaseName string = database.name
output databaseResourceId string = database.id
