targetScope = 'resourceGroup'

param name string
param location string
param environment string
param tags object = {}

param skuName string = 'PerGB2018'

var resourceName = '${name}-${environment}-workspace'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: resourceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: skuName
    }
    retentionInDays: 30
  }
}

output resourceId string = logAnalyticsWorkspace.id
