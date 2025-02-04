targetScope = 'resourceGroup'

param name string
param location string
param environment string
param tags object = {}

@description('The name of the SKU found via az mysql flexible-server list-skus -l eastus -o table')
param skuName string = 'Standard_B1ms'

param adminLogin string
@secure()
param adminPassword string
param databaseName string = 'strapi'

var resourceName = '${name}-${environment}-mysql'

resource mysqlFlexible 'Microsoft.DBforMySQL/flexibleServers@2021-12-01-preview' = {
  name: resourceName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
  }
}

resource database 'Microsoft.DBforMySQL/flexibleServers/databases@2021-12-01-preview' = {
  name: databaseName
  parent: mysqlFlexible
}

output fqdn string = mysqlFlexible.properties.fullyQualifiedDomainName
output databaseName string = database.name
