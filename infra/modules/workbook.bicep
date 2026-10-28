import { ResourceGroupInputs } from './_types.bicep'

param inputs ResourceGroupInputs
param appInsightsId string

resource workbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('workbook-${inputs.global.baseName}-${inputs.global.environment}')
  location: inputs.global.location
  tags: inputs.tags
  kind: 'shared'
  properties: {
    displayName: 'Memorywell Observability'
    serializedData: '{"version":"Notebook/1.0","items":[{"type":3,"content":"Memorywell workbook (flag rate panel placeholder)","name":"text"}]}'
    sourceId: appInsightsId
    category: 'workbook'
  }
}

output id string = workbook.id
