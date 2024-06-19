targetScope = 'subscription'

param location string

@description('Tags retrieved from parameter file.')
param resourceTags object = {}
@description('Name of DevBox definition.')
param definitionName string = 'DevBox-8-32'
@description('DevBox definition SKU.')
param definitionSKU string = 'general_i_8c32gb256ssd_v2'
@description('DevBox definition storage type.')
param definitionStorageType string = 'ssd_256gb'

resource rg_devc 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-devcenter'
  location: location
  tags: resourceTags
}

param vnetName string = 'core-vnet-weu'
module vnet 'br/public:network/virtual-network:1.1.3' = {
  scope: rg_devc
  name: 'core-vnet-weu'
  params: {
    name: vnetName
    location: location    
    addressPrefixes: [
      '10.1.0.0/16'
    ]
    subnets: [
      {
        name: 'snet-devbox-01'
        addressPrefix: '10.1.1.0/24'
        privateEndpointNetworkPolicies: 'Enabled'
      }
      {
        name: 'snet-cae-01'
        addressPrefix: '10.1.2.0/24'
        privateEndpointNetworkPolicies: 'Enabled'
        delegations: [
          {            
            name: 'Microsoft.App.environments'
            properties: {
              serviceName: 'Microsoft.App/environments'
            }
            type: 'Microsoft.Network/virtualNetworks/subnets/delegations'
          }
        ]
      }    
    ]
  }
}

module devCenter '../modules/devcenters/devcenter/main.bicep' = {
  scope: rg_devc
  name: 'devcenter'
  params: {
    location: location
    devCenterName: 'devCenter'
    definitionName: definitionName
    definitionSKU: definitionSKU
    definitionStorageType: definitionStorageType
    image: 'microsoftvisualstudio_visualstudioplustools_vs-2022-ent-general-win11-m365-gen2'
    networkConnectionId: networkConnection.outputs.id    
  }
}

module devProject '../modules/devcenters/project/main.bicep' = {
  scope: rg_devc
  name: 'devProject'
  params: {
    devBoxDefinitionName: definitionName
    devCenterId: devCenter.outputs.devCenterId
    devPoolName: 'devBoxPool'
    location: location
    networkConnectionName: devCenter.outputs.devCenterAttachedNetwork
    projectName: 'devProject'
    deploymentTargetId: subscription().id
  }
}

//Add permissions for the dev environment identity to modify the vnet
var networkContributorRole = resourceId('Microsoft.Authorization/roleAssignments','4d97b98b-1d4f-4787-a291-c67834d212e7')
resource networkRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(rg_devc.id,devCenter.name,networkContributorRole)
  properties: {
    principalId: devProject.outputs.devEnvironmentManagedId
    roleDefinitionId: networkContributorRole
    principalType: 'ServicePrincipal'
  }
}

//Connect the Dev Center to the custom vnet
module networkConnection '../modules/devcenters/network-connection/main.bicep' = {
  scope: rg_devc
  name: 'devcenter-network-connection'
  params: {
    connectionName: 'devcenter-network-connection'
    location: location
    snetId: vnet.outputs.subnetResourceIds[0]
  }
}
