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

// A rediss:// URL, not listKeys().primaryConnectionString. The Azure form is
// `host:6380,password=...,ssl=True` — not a URL, so every client has to
// hand-parse it (seed.py grew a parser for exactly this). The rediss:// scheme
// also matches the account: enableNonSslPort is false, so TLS is mandatory and
// the scheme states it.
//
// 6380 is the fixed Azure Redis TLS port; the resource exposes no port property.
// uriComponentToString() percent-encodes the key. Azure keys are alphanumeric
// today so it is a no-op, but it keeps a future key with reserved characters from
// silently truncating the URL.
@secure() // going to prod should use Entra ACL user instead of key: this bakes
// the key in at deploy time, so a rotation breaks the connection until the next
// provision-env.sh. An Entra ACL user removes that and the secret with it.
output connectionUrl string = 'rediss://:${uriComponentToString(cache.listKeys().primaryKey)}@${cache.properties.hostName}:6380'
