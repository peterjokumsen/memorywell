param name string
param location string
param sku string = 'Free'
param cosmosAccountEndpoint string = ''
param identityClientId string = ''

resource swa 'Microsoft.Web/staticSites@2023-12-01' = {
  name: name
  location: location
  sku: {
    name: sku
    tier: sku
  }
  properties: {}
}

resource appSettings 'Microsoft.Web/staticSites/config@2023-12-01' = {
  parent: swa
  name: 'appsettings'
  properties: {
    CosmosDBConnection__accountEndpoint: cosmosAccountEndpoint
    CosmosDBConnection__credential: 'managedidentity'
    CosmosDBConnection__clientId: identityClientId
    COSMOS_DATABASE: 'memorywell'
  }
}

output appUrl string = 'https://${swa.properties.defaultHostname}'
