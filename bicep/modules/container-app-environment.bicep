targetScope = 'resourceGroup'

param name string
param location string
param environment string
param tags object = {}

param workspaceResourceName string

var resourceName = '${name}-${environment}-cae'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
  name: workspaceResourceName
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: resourceName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    zoneRedundant: false
  }
}


output managedEnvironmentId string = containerAppsEnvironment.id
