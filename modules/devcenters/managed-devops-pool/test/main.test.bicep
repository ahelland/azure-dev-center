targetScope = 'subscription'

param location string = 'westeurope'

param resourceTags object = {
  value: {
    IaC: 'Bicep'
    Environment: 'Test' 
  }
}

resource rg_devc 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-devcenter'
  location: location
  tags: resourceTags
}

module pool '../main.bicep' = {
  scope: rg_devc
  name: 'managedPool'
  params: {
    location: location
    azdoOrganization: 'fooOrg'
    devCenterProjectResourceId: '1234'
    poolName: 'pool-01'
    subnetId: '/subscriptions/subId/resourceGroups/rg-devcenter/providers/Microsoft.Network/virtualNetworks/core-vnet-weu/subnets/snet-pool-01'
  }
}
