param name string
param amount int = 50

resource budget 'Microsoft.Consumption/budgets@2023-05-01' = {
  name: name
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: '2026-01-01T00:00:00Z'
    }
    notifications: {
      Actual_GreaterThan_80: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 80
        contactEmails: []
      }
    }
  }
}
