# Phase 2 · Step 1 — Group A: Cosmos DB

**Group A — Cosmos DB (`infra/modules/cosmos.bicep`, new).** Account
(serverless capability, cheapest tier), one database (`memorywell`),
containers: `households`, `chronicles`, `contributors`, `invites`,
`prompts`, `memories`, `transcripts`, `flags`, `aliasHistory`.
Partition keys: `/householdId` for household-scoped containers,
`/chronicleId` for chronicle-scoped ones (`memories`, `prompts`,
`transcripts`, `flags`, `aliasHistory`). Consistency: `Session`.
Indexing policy: default + excluded paths for large blob-payload fields if
you add any (keep default otherwise and note why). Vector index on
`memories.embedding` (flat index, cosine; dimensions recorded below —
suggested `1536` for `text-embedding-3-small`, your choice, document it).
Nothing else in this step — no Postgres, no Redis, no secrets.

Stub shape (write it yourself, keep it this small):

```bicep
// infra/modules/cosmos.bicep — stub
resource account 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: 'cosmos-${inputs.global.baseName}-${inputs.global.environment}'
  location: inputs.global.location
  kind: 'GlobalDocumentDB'
  properties: {
    capabilities: [{ name: 'EnableServerless' }]
    consistencyPolicy: { defaultConsistencyLevel: 'Session' }
    databaseAccountOfferType: 'Standard'
    locations: [{ locationName: inputs.global.location, failoverPriority: 0 }]
  }
}
```

Vector dimensions (record your choice here when you build): suggested
`1536` (`text-embedding-3-small`, used by Curator in Phase 4b). Cosmos
vector path `memories.embedding` and Postgres `embedding vector(<dims>)`
([step-2.md](./step-2.md)) must use the same number.

## Verify

- [x] Portal/CLI shows Cosmos serverless account + 9 containers; `memories`
      has the vector index; consistency is `Session`.
- [x] Account is tagged with the env tags (same pattern as `vault.bicep`), and
      the module exports `accountName` / `accountEndpoint` / `databaseName` for
      step-4 wiring.
