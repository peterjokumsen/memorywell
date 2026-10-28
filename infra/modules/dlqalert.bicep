import { ResourceGroupInputs } from './_types.bicep'

param inputs ResourceGroupInputs
param serviceBusNamespace string
param actionGroupId string = ''

resource alert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'dlq-${inputs.global.baseName}-${inputs.global.environment}'
  location: 'global'
  tags: inputs.tags
  properties: {
    description: 'Dead-letter queue depth alert'
    severity: 2
    enabled: true
    scopes: [
      resourceId('Microsoft.ServiceBus/namespaces', serviceBusNamespace)
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'DLQDepth'
          metricName: 'DeadletteredMessages'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Total'
        }
      ]
    }
    actions: empty(actionGroupId)
      ? []
      : [
          { actionGroupId: actionGroupId }
        ]
  }
}

output id string = alert.id
