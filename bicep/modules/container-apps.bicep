targetScope = 'resourceGroup'

param name string
param location string
param environment string
param tags object = {}
param managedEnvironmentId string
param secrets array = []
param containerImage string
param containerName string
param containerCommand array = []
param containerTargetPort int
param containerEnvironmentVariables array = []
param containerResourcesCPU int = 1
param containerResourcesMemory string = '2Gi'
param containerMinReplicas int = 1
param containerMaxRepliacs int = 1

param currentUtc string = utcNow()

var resourceName = '${name}-${environment}-ca'

resource backendcms 'Microsoft.App/containerApps@2022-03-01' = {
  name: resourceName
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: managedEnvironmentId
    configuration: {
      secrets: secrets
      activeRevisionsMode: 'multiple'
      ingress: {
        external: true
        targetPort: containerTargetPort
        transport: 'auto'
        traffic: [
          {
            revisionName: '${name}-${currentUtc}'
            weight: 100
          }
        ]
        allowInsecure: false
      }
      registries: []
    }
    template: {
      containers: [
        {
          image: containerImage
          name: containerName
          command: containerCommand
          env: containerEnvironmentVariables
          resources: {
            cpu: containerResourcesCPU
            memory: containerResourcesMemory
          }
          probes: []
        }
      ]
      scale: {
        minReplicas: containerMinReplicas
        maxReplicas: containerMaxRepliacs
      }
    }
  }
  identity: {
    type: 'None'
  }
}

output fqdn string = backendcms.properties.configuration.ingress.fqdn
