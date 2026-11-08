param appInsightsConnectionString string
param name string
param location string
param sku string = 'Free'

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
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsConnectionString
  }
}

output appUrl string = 'https://${swa.properties.defaultHostname}'
