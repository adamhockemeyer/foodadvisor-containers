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
param containerResourcesCPU string = '1'
param containerResourcesMemory string = '2Gi'
param containerMinReplicas int = 1
param containerMaxRepliacs int = 1

param currentUtc string = utcNow()

var resourceName = '${name}-${environment}-ca'

resource containerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: resourceName
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: managedEnvironmentId
    configuration: {
      secrets: secrets
      //activeRevisionsMode: 'Multiple'
      ingress: {
        external: true
        targetPort: containerTargetPort
        transport: 'auto'
        traffic: [
          {
            latestRevision: true
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
            cpu: json(containerResourcesCPU)
            memory: containerResourcesMemory
          }
          probes: []
        }
      ]
      revisionSuffix: toLower(currentUtc)
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

output fqdn string = containerApp.properties.configuration.ingress.fqdn
