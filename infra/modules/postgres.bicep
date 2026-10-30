import { ResourceGroupInputs } from './_types.bicep'

param inputs ResourceGroupInputs
param administratorLogin string
@secure()
param administratorPassword string

// Flexible Server built-in pooler on PG14+, small max_connections on a 2-vCPU B1ms, Phase 3 opening one pool per agent container
resource server 'Microsoft.DBforPostgreSQL/flexibleServers@2025-08-01' = {
  name: 'pg-${inputs.global.baseName}-${inputs.global.environment}'
  location: inputs.global.location
  tags: inputs.tags
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '16'
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    storage: {
      storageSizeGB: 32
      autoGrow: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    backup: {
      backupRetentionDays: 7
    }
    network: {
      publicNetworkAccess: 'Enabled'
    }
  }
}

resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2025-08-01' = {
  parent: server
  name: 'memorywell'
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

resource azureExtensions 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2025-08-01' = {
  parent: server
  name: 'azure.extensions'
  properties: {
    value: 'vector'
    source: 'user-override'
  }
}

resource clientFirewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2025-08-01' = {
  parent: server
  name: 'allow-client'
  properties: {
    startIpAddress: inputs.global.postgresClientIp
    endIpAddress: inputs.global.postgresClientIp
  }
}

output serverName string = server.name
output serverFqdn string = server.properties.fullyQualifiedDomainName
output databaseName string = database.name

// A postgresql:// URL, not the ADO.NET `Host=…;Port=…` form. psycopg3 accepts
// only a URI or libpq keyword/value conninfo (`host=`, `dbname=`, …); handed the
// ADO string it fails with `invalid connection option "Host"`. The URL also
// matches how the value is used everywhere: `psycopg.connect(URL)`.
//
// uriComponentToString() percent-encodes login and password. The password comes
// from .env, so it can hold `@ : / ? #` — unescaped those truncate the URL into
// a wrong host and a silent auth failure rather than an error at parse time.
// sslmode=require states what the server enforces anyway: Azure PG rejects
// non-TLS connections, and psycopg's `prefer` default leaves that to negotiation.
@secure()
output connectionString string = 'postgresql://${uriComponentToString(administratorLogin)}:${uriComponentToString(administratorPassword)}@${server.properties.fullyQualifiedDomainName}:5432/${database.name}?sslmode=require'
