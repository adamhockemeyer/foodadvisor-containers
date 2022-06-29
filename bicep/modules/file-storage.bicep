targetScope = 'resourceGroup'

param name string
param location string
param environment string
param tags object = {}
@allowed([
  'Premium_LRS' // Premium fireshare requires 100GiB minumim fileshare size 
  'Premium_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_LRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Standard_ZRS'
])
param sku string = 'Standard_GZRS'
param fileServiceName string = 'containerapp-files'
param fileShareName string = 'containerapp-mount'

var resourceName = substring(replace('${name}-${environment}-sa', '-', ''), 0, 24)

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: resourceName
  location: location
  sku: {
    name: sku
  }
  properties: {
    allowBlobPublicAccess: false
  }
  kind: 'StorageV2'
  tags: tags
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2021-09-01' = {
  name: fileServiceName
  parent: storageAccount
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-09-01' = {
  name: fileShareName
  parent: fileService
  properties: {
    enabledProtocols: 'SMB'
    shareQuota: 5
  }
}

output storageAccountName string = storageAccount.name
output fileShareName string = fileShare.name
