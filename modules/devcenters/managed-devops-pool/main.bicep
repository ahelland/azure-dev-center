metadata name = 'Managed DevOps Pool'
metadata description = 'Managed DevOps Pool'
metadata owner = 'ahelland'

@description('Specifies the location for resources.')
param location string
@description('Name of DevCenter')
param poolName string
@description('Subnet id of the subnet the managed pool should be attached to.')
param subnetId string

@description('Tags retrieved from parameter file.')
param resourceTags object = {}
@description('Azure DevOps organization (for example the "foo" section of https://dev.azure.com/foo)')
param azdoOrganization string
@description('Id of the DevCenter to attach project to.')
param devCenterProjectResourceId string
@description('Max number of agents.')
param poolSize int = 1
@description('Image to use for pool.')
param wellKnownImageName string = 'ubuntu-22.04/latest'
@description('Compute SKU for agent.')
param sku string = 'Standard_DS1_v2'

resource pool 'Microsoft.DevOpsInfrastructure/pools@2024-04-04-preview' = {
  name: poolName
  location: location
  tags: resourceTags
  properties: {
    organizationProfile: {
      kind: 'AzureDevOps'
      organizations: [
        {
          url: 'https://dev.azure.com/${azdoOrganization}'
          parallelism: 1
        }
      ]
    }
    agentProfile: {
      kind: 'Stateless'
    }
    devCenterProjectResourceId: devCenterProjectResourceId
    fabricProfile: {
      sku: {
        name: sku
      }
      storageProfile: {
        osDiskStorageAccountType: 'Standard'
        dataDisks: []
      }
      images: [
        {
          wellKnownImageName: wellKnownImageName
          buffer: '*'
        }
      ]
      osProfile: {
        secretsManagementSettings: {
          observedCertificates: []
          keyExportable: false
        }
        logonType: 'Service'
      }
      networkProfile: {
        subnetId: subnetId
      }
      kind: 'Vmss'
    }
    maximumConcurrency: poolSize
  }
}
