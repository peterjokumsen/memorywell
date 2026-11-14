# Web API (BFF)

`web/api` is an Azure Functions app acting as the backend-for-frontend for all entities.

## Entities

households, chronicles, contributors, invites, prompts, memories, transcripts, flags, aliasHistory.

## Endpoints

For each entity `{e}`:

- GET `/{e}` list (filters via query params; soft-deleted excluded unless `includeDeleted=true`)
- GET `/{e}/{id}` read
- POST `/{e}` create
- PUT `/{e}/{id}` replace
- PATCH `/{e}/{id}` partial update
- DELETE `/{e}/{id}` soft delete

OpenAPI spec: `GET /openapi.json`.

## Local development (SWA + BFF)

- Web calls the BFF through the SWA `/api` proxy using relative paths (no `VITE_API_BASE_URL`).
- Run BFF: `cd bff && func start --port 7071`
- Run web: `cd web && npm run dev`
- Run SWA proxy: `cd web && npm run dev:swa`
- Open `http://localhost:4280`.

## Type generation

Run `npm run generate:api-types` in `web/` to generate `src/api/types.generated.ts`.
