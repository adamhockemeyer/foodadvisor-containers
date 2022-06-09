targetScope = 'resourceGroup'

param name string
param location string
param environment string
param tags object = {}

param workspaceResourceId string

var resourceName = '${name}-${environment}-ai'

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: resourceName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceResourceId
  }
}
