targetScope = 'resourceGroup'

param name string
param location string
param environment string
param tags object = {}

param workspaceResourceId string

var resourceName = '${name}-${environment}-cae'

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: resourceName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: workspaceResourceId
      }
    }
    zoneRedundant: false
  }
}

output managedEnvironmentId string = containerAppsEnvironment.id
