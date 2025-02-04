targetScope = 'subscription'

param location string = deployment().location
@allowed([
  'dev'
  'test'
  'qa'
  'prod'
])
param environment string = 'dev'
param namePrefix string = 'container-apps-food-${uniqueString(subscription().id, location, environment)}'

param defaultTags object = {
  Department: 'R&D'
  Environment: environment
  Updated: utcNow()
  ManagedBy: 'Bicep'
  Owner: 'group@org.com'
}

var resourceGroupName = '${namePrefix}-rg'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: defaultTags
}

module logAnalytics './modules/log-analytics.bicep' = {
  name: 'log-analytics-workspace'
  scope: rg
  params: {
    name: namePrefix
    location: rg.location
    environment: environment
    tags: defaultTags
  }
}

module applicationInsights 'modules/app-insights.bicep' = {
  name: 'application-insights'
  scope: rg
  params: {
    name: namePrefix
    location: rg.location
    environment: environment
    tags: defaultTags
    workspaceResourceId: logAnalytics.outputs.resourceId
  }
}

// For demo purposes, we are using a MySQL database. In a production environment, you should use more secure credentials.
var mysqlAdminLogin = 'mysqladmin'
var mySqlAdminPassword = uniqueString(rg.id, environment, 'mysql-admin-password')

module mysql 'modules/mysql-flexible.bicep' = {
  scope: rg
  name: 'mysql'
  params: {
    name: namePrefix
    location: location
    environment: environment
    tags: defaultTags
    adminLogin: mysqlAdminLogin
    adminPassword: mySqlAdminPassword
  }
}

module containerAppsEnvironment 'modules/container-app-environment.bicep' = {
  name: 'container-apps-environment'
  scope: rg
  params: {
    name: namePrefix
    location: location
    environment: environment
    tags: defaultTags
    workspaceResourceName: logAnalytics.outputs.resourceName
  }
}

var previewSecret = uniqueString(rg.id, environment, containerAppsEnvironment.name)
var adminJwtSecret = uniqueString(rg.id, environment, containerAppsEnvironment.name, 'admin-jwt-secret')
var apiSaltToken = uniqueString(rg.id, environment, containerAppsEnvironment.name, 'api-salt-token')
var jwtSecret = uniqueString(rg.id, environment, containerAppsEnvironment.name, 'jwt-secret')

module conatinerApp_Backend 'modules/container-apps.bicep' = {
  name: 'container-app-backend'
  scope: rg
  params: {
    name: 'backend'
    location: rg.location
    environment: environment
    tags: defaultTags
    managedEnvironmentId: containerAppsEnvironment.outputs.managedEnvironmentId
    secrets: [
      {
        name: 'mysql-admin-login'
        value: mysqlAdminLogin
      }
      {
        name: 'mysql-admin-password'
        value: mySqlAdminPassword
      }
      {
        name: 'admin-jwt-secret'
        value: adminJwtSecret
      }
      {
        name: 'api-salt-token'
        value: apiSaltToken
      }
      {
        name: 'jwt-secret'
        value: jwtSecret
      }
      {
        name: 'strapi-admin-client-preview-secret'
        value: previewSecret
      }
      {
        name: 'app-insights-connection-string'
        value: applicationInsights.outputs.connectionString
      }
    ]
    containerImage: 'ghcr.io/adamhockemeyer/foodadvisor-containers-api:master'
    containerName: 'strapi'
    containerTargetPort: 1337
    containerEnvironmentVariables: [
      {
        name: 'DATABASE_HOST'
        value: mysql.outputs.fqdn
      }
      {
        name: 'DATABASE_PORT'
        value: '3306'
      }
      {
        name: 'DATABASE_NAME'
        value: mysql.outputs.databaseName
      }
      {
        name: 'DATABASE_USERNAME'
        secretRef: 'mysql-admin-login'
      }
      {
        name: 'DATABASE_PASSWORD'
        secretRef: 'mysql-admin-password'
      }
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        secretRef: 'app-insights-connection-string'
      }
      {
        name: 'STRAPI_ADMIN_CLIENT_URL'
        value: 'TBD'
      }
      {
        name: 'STRAPI_ADMIN_CLIENT_PREVIEW_SECRET'
        secretRef: 'strapi-admin-client-preview-secret'
      }
      {
        name: 'PORT'
        value: '1337'
      }
      {
        name: 'API_TOKEN_SALT'
        secretRef: 'api-salt-token'
      }
      {
        name: 'JWT_SECRET'
        secretRef: 'jwt-secret'
      }
      {
        name: 'ADMIN_JWT_SECRET'
        secretRef: 'admin-jwt-secret'
      }
    ]
  }
}

module conatinerApp_Frontend 'modules/container-apps.bicep' = {
  name: 'container-app-frontend'
  scope: rg
  params: {
    name: 'frontend'
    location: rg.location
    environment: environment
    tags: defaultTags
    managedEnvironmentId: containerAppsEnvironment.outputs.managedEnvironmentId
    secrets: [
      {
        name: 'preview-secret'
        value: previewSecret
      }
    ]
    containerImage: 'ghcr.io/adamhockemeyer/foodadvisor-containers-client:master'
    containerName: 'frontend'
    containerTargetPort: 3000
    containerEnvironmentVariables: [
      {
        name: 'NEXT_PUBLIC_API_URL'
        value: 'https://${conatinerApp_Backend.outputs.fqdn}'
      }
      {
        name: 'PREVIEW_SECRET'
        secretRef: 'preview-secret'
      }
    ]
  }
}

// Update the backend container app environment variables if this is the first time deploying the front end
