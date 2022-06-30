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
@description('If mounting a volume, provide a name along with the volumeMountPath and volumeAzureFilesStorageName')
param volumeName string = ''
@description('If using sqlite, we can mount a volume to the container for persistant storage.')
param volumeMountPath string = ''
@description('If using sqlite, we can mount Azure Files as a volume to mount.')
param volumeAzureFilesStorageName string = ''
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
      activeRevisionsMode: 'multiple'
      ingress: {
        external: true
        targetPort: containerTargetPort
        transport: 'auto'
        traffic: [
          {
            latestRevision: true
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
          volumeMounts: (!empty(volumeAzureFilesStorageName) && !empty(volumeMountPath) && !empty(volumeName)) ? [
            {
              volumeName: volumeName
              mountPath: volumeMountPath
            }
          ] : []
          probes: []
        }
      ]
      volumes: (!empty(volumeAzureFilesStorageName) && !empty(volumeMountPath) && !empty(volumeName)) ? [
        {
          name: volumeName
          storageType: 'AzureFile'
          storageName: volumeAzureFilesStorageName
        }
      ] : []
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
