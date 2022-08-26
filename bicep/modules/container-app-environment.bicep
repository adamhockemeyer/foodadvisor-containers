targetScope = 'resourceGroup'

param name string
param location string
param environment string
param tags object = {}
@description('If mounting storage, include the storage account name, otherwise leave empty.')
param storageAccountName string = ''
@description('If mounting storage, provide the file share name, otherwise leave empty.')
param fileShareName string = ''

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

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' existing = if (!empty(storageAccountName)) {
  name: storageAccountName
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-09-01' existing = if (!empty(fileShareName)) {
  name: fileShareName
}

resource containerAppsEnvironmentStorage 'Microsoft.App/managedEnvironments/storages@2022-03-01' = if (storageAccount.id != null && fileShare.id != null) {
  name: 'storage'
  parent: containerAppsEnvironment
  properties: {
    azureFile: {
      accountKey: storageAccount.listKeys().keys[0].value
      accountName: storageAccount.name
      shareName: fileShare.name
      accessMode: 'ReadWrite'
    }
  }
}

output managedEnvironmentId string = containerAppsEnvironment.id
output environmentStorageName string = containerAppsEnvironmentStorage.name
