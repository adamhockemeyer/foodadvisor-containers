targetScope = 'subscription'

param namePrefix string = 'container-apps-food-${uniqueString(subscription().id)}'
param location string = deployment().location
@allowed([
  'dev'
  'test'
  'qa'
  'prod'
])
param environment string = 'dev'
@allowed([
  'sqlite'
])
param databaseType string = 'sqlite'
param defaultTags object = {
  Department: 'R&D'
  Environment: environment
  Updated: utcNow()
  ManagedBy: 'Bicep'
  Owner: 'group@org.com'
}

var resourceGroupName = '${namePrefix}-rg'
var isSqlite = databaseType == 'sqlite'


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

module fileStorage 'modules/file-storage.bicep' = if (isSqlite) {
  name: 'file-storage'
  scope: rg
  params: {
    name: namePrefix
    location: location
    environment: environment
    tags: defaultTags
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
    //storageAccountName: isSqlite ? fileStorage.outputs.storageAccountName : ''
    //fileShareName: isSqlite ? fileStorage.outputs.fileShareName : ''
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
    //volumeName: isSqlite ? 'azure-files-volume' : ''
    //volumeAzureFilesStorageName: isSqlite ? containerAppsEnvironment.outputs.environmentStorageName : ''
    //volumeMountPath: isSqlite ? '/file-mount' : ''
    secrets: [
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
      // isSqlite ? {
      //   name: 'DATABASE_FILENAME'
      //   value: 'file-mount/data.db'
      // } : {}
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
        value: conatinerApp_Backend.outputs.fqdn
      }
      {
        name: 'PREVIEW_SECRET'
        secretRef: 'preview-secret'
      }
    ]
  }
}

// Update the backend container app environment variables if this is the first time deploying the front end
