# Nx Workspace (memorywell)

Root grouping folders:

- `apps/` — deployable frontends (Angular PWA + Angular Material).
- `libs/` — shared TypeScript libraries.
- `bffs/` — backend-for-frontend layers.
- `backends/` — C# .NET 10 services.

Nx config: `nx.json`. Package manager: pnpm.

Common commands:

- `pnpm nx graph`
- `pnpm nx run-many -t build,test,lint`
- `pnpm nx affected -t test`
  EOF
