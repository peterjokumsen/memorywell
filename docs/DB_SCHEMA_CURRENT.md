# Current Database Schema (pre-overhaul)

Snapshot of data stores as implemented today. Source of truth: `scripts/seed.py`,
`infra/modules/cosmos.bicep`, `infra/modules/postgres.bicep`.

## Cosmos DB (database `memorywell`)

Nine containers, partition keys as listed.

| Container    | Partition key | Notes                                                                                                                                                                                                         |
| ------------ | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| households   | /id           | `{id, name, createdAt}`                                                                                                                                                                                       |
| chronicles   | /householdId  | `{id, householdId, name, createdAt}`                                                                                                                                                                          |
| contributors | /householdId  | owner-managed fields (contact, relation, status) + per-chronicle `displayAlias`, `promptCadence` maps                                                                                                         |
| invites      | /householdId  |                                                                                                                                                                                                               |
| prompts      | /chronicleId  |                                                                                                                                                                                                               |
| memories     | /chronicleId  | vector index on `/embedding` (float32, cosine, 1536 dims); fields: id, householdId, chronicleId, contributorId, aliasAtWriteTime, body, topic, promptId, parentMemoryId, turnCount, conversationId, createdAt |
| transcripts  | /chronicleId  |                                                                                                                                                                                                               |
| flags        | /chronicleId  |                                                                                                                                                                                                               |
| aliasHistory | /chronicleId  |                                                                                                                                                                                                               |

Seed data: 1 household, 2 chronicles, 4 contributors, 1 memory.

## Postgres (documents table)

```sql
CREATE EXTENSION IF NOT EXISTS vector;
CREATE TABLE IF NOT EXISTS documents (
  id            uuid PRIMARY KEY,
  "chronicleId"   text,
  "contributorId" text,
  topic         text,
  "createdAt"     timestamptz,
  embedding     vector(1536),
  metadata      jsonb
);
```

`id` = `uuid5(NAMESPACE_URL, cosmos memory id)` (stable). `embedding` left NULL at seed; filled later via change feed.

## Redis

Alias-lookup key (`ALIAS_LOOKUP_KEY`) stores JSON map contributorId -> displayAlias. No TTL at seed.
