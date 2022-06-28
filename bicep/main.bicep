targetScope = 'subscription'

param namePrefix string = 'container-apps-food-${uniqueString(subscription().id)}'
param region string = 'eastus'
@allowed([
  'dev'
  'test'
  'qa'
  'prod'
])
param environment string = 'dev'
param defaultTags object = {
  Department: 'R&D'
  Environment: environment
  Updated: utcNow('d')
  ManagedBy: 'Bicep'
  Owner: 'group@org.com'
}

var resourceGroupName = '${namePrefix}-rg'
var location = region

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

module containerAppsEnvironment 'modules/container-app-environment.bicep' = {
  name: 'container-apps-environment'
  scope: rg
  params: {
    name: namePrefix
    location: location
    environment: environment
    workspaceResourceId: logAnalytics.outputs.resourceId
  }
}

var previewSecret = uniqueString(rg.id, environment, containerAppsEnvironment.name)

module conatinerApp_Backend 'modules/container-apps.bicep' = {
  name: 'container-app-backend'
  scope: rg
  params: {
    name: '${namePrefix}-backend'
    location: rg.location
    environment: environment
    tags: defaultTags
    managedEnvironmentId: containerAppsEnvironment.outputs.managedEnvironmentId
    secrets: [
      {
        name: 'admin-jwt-secret'
      }
      {
        name: 'api-salt-token'
      }
      {
        name: 'jwt-secret'
      }
    ]
    containerImage: 'ghcr.io/adamhockemeyer/foodadvisor-containers-api:master'
    containerName: 'strapi'
    containerTargetPort: 1337
    containerEnvironmentVariables: [
      {
        name: 'STRAPI_ADMIN_CLIENT_URL'
        value: 'TBD'
      }
      {
        name: 'STRAPI_ADMIN_CLIENT_PREVIEW_SECRET'
        secretRef: previewSecret
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
    name: '${namePrefix}-frontend'
    location: rg.location
    environment: environment
    tags: defaultTags
    managedEnvironmentId: containerAppsEnvironment.outputs.managedEnvironmentId
    secrets: []
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
        value: previewSecret
      }
    ]
  }
}

// Update the backend container app environment variables if this is the first time deploying the front end
