import { ResourceGroupInputs } from './_types.bicep'

param inputs ResourceGroupInputs
param workspaceId string

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'ai-${inputs.global.baseName}-${inputs.global.environment}'
  location: inputs.global.location
  tags: inputs.tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceId
  }
}

output name string = appInsights.name
output connectionString string = appInsights.properties.ConnectionString
output instrumentationKey string = appInsights.properties.InstrumentationKey
