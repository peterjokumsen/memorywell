import { ResourceGroupInputs } from './_types.bicep'

param inputs ResourceGroupInputs

resource cache 'Microsoft.Cache/redis@2024-03-01' = {
  name: 'redis-${inputs.global.baseName}-${inputs.global.environment}'
  location: inputs.global.location
  tags: inputs.tags
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0
    }
    enableNonSslPort: false // dev only, prod hardening will need VNet
    minimumTlsVersion: '1.2'
  }
}

output cacheName string = cache.name
output hostName string = cache.properties.hostName
@secure() // going to prod should use Entra ACL user instead of key
output connectionString string = cache.listKeys().primaryKey
