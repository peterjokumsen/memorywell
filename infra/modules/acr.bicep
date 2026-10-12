param location string
param registryName string
param tags object

resource acr 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: registryName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

output registryName string = acr.name
output loginServer string = acr.properties.loginServer
