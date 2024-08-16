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
@description('Azure DevOps organization (for example the "foo" section of https://dev.azure.com/foo)')
param azdoOrganization string
@description('The objectId of the "DevOpsInfrastructure" application in Entra ID.')
param devOpsSPId string

resource rg_devc 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-devcenter-pool'
  location: location
  tags: resourceTags
}

param vnetName string = 'core-vnet-neu'
module vnet 'br/public:network/virtual-network:1.1.3' = {
  scope: rg_devc
  name: 'core-vnet-neu'
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
      {
        name: 'snet-pool-01'
        addressPrefix: '10.1.3.0/24'
        privateEndpointNetworkPolicies: 'Enabled'
        delegations: [
          {            
            name: 'Microsoft.App.environments'
            properties: {
              serviceName: 'Microsoft.DevOpsInfrastructure/pools'
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
  name: 'devcenter-pool'
  params: {
    location: location
    devCenterName: 'devCenter-pool'
    definitionName: definitionName
    definitionSKU: definitionSKU
    definitionStorageType: definitionStorageType
    image: 'microsoftvisualstudio_visualstudioplustools_vs-2022-ent-general-win11-m365-gen2'
    networkConnectionId: networkConnection.outputs.id    
  }
}

module devProject '../modules/devcenters/project/main.bicep' = {
  scope: rg_devc
  name: 'devProject-pool'
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
resource networkRoleAssignmentDevEnvironment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(rg_devc.id,devCenter.name,networkContributorRole)
  properties: {
    principalId: devProject.outputs.devEnvironmentManagedId
    roleDefinitionId: networkContributorRole
    principalType: 'ServicePrincipal'
  }
}

//Add permissions for the Azure DevOps Service Principal
//For network integration
resource networkRoleAssignmentDevOpsSP 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(rg_devc.id,devCenter.name,networkContributorRole,'DevOpsInfrastructure')
  properties: {
    principalId: devOpsSPId
    roleDefinitionId: networkContributorRole
    principalType: 'ServicePrincipal'
  }
}

//For reader access (applied to subscription scope here)
var readerRole = resourceId('Microsoft.Authorization/roleAssignments','acdd72a7-3385-48ef-bd42-f606fba81ae7')
resource readerRoleAssignmentDevOpsSP 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(rg_devc.id,devCenter.name,readerRole,'DevOpsInfrastructure')
  properties: {
    principalId: devOpsSPId
    roleDefinitionId: readerRole
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

//Connect the DevOps Pool to a dedicated subnet
module managedPool '../modules/devcenters/managed-devops-pool/main.bicep' = {
  scope: rg_devc
  name: 'devcenter-managed-pool'
  params: {
    resourceTags: resourceTags
    location: location
    azdoOrganization: azdoOrganization
    devCenterProjectResourceId: devProject.outputs.devProjectId
    poolName: 'azdo-mg-pool-01'
    subnetId: vnet.outputs.subnetResourceIds[2]
  }
  dependsOn: [
    networkRoleAssignmentDevOpsSP
  ]
}
