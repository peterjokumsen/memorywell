// Applies tags to the resource group this deployment is scoped to.
//
// Microsoft.Resources/tags is an extension resource: it has no resourceId
// property, only `tags`, and reaches its target through the deployment scope.
// That forces a resource group scope file — main.bicep's targetScope is the
// subscription, where the same resource is rejected with BCP139.
targetScope = 'resourceGroup'

param tags object

resource rgTags 'Microsoft.Resources/tags@2021-04-01' = {
  name: 'default'
  properties: {
    tags: tags
  }
}
