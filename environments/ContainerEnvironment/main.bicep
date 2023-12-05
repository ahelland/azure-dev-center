metadata name = 'Container Environment - Azure'
metadata description = 'Deploys a Container Environment in Azure.'
metadata owner = 'ahelland'

@description('Name of Container Environment')
param name string
@description('Location for Container Environment')
param location string
@description('Tags retrieved from parameter file.')
param resourceTags object = {}

@description('Should the Container Environment be connected to a custom virtual network? Enabling this also requires a valid value for snetId.')
param vnetInternal bool = true
@description('If vnet integration is enabled which subnet should the container environment be connected to?')
param snetId string

//Include Log Analytics in module to avoid passing clientSecret via outputs
resource loganalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-analytics-${name}'
  location: location
  tags: resourceTags
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

resource containerenvironment 'Microsoft.App/managedEnvironments@2023-05-02-preview' = {
  name: 'container-environment-${name}'
  location: location  
  tags: resourceTags
  properties: {    
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: loganalytics.properties.customerId
        sharedKey: loganalytics.listKeys().primarySharedKey
      }
    }
    vnetConfiguration: {
      internal: vnetInternal ? true : false
      //If vnetInternal == false, snetId is assumed to be null.      
      infrastructureSubnetId: snetId
    }
    peerAuthentication: {
      mtls: {
        enabled: true
      }
    }
    workloadProfiles: [
      {
        workloadProfileType: 'Consumption'
        name: 'Consumption'
      }
    ]
  }  
}

//Split the subnetId into individual parts to build the vnetId part
//Note: this is a quick hack type implementation
var vnetComponents = split(snetId,'/')
var vnetId = '/${vnetComponents[1]}/${vnetComponents[2]}/${vnetComponents[3]}/${vnetComponents[4]}/${vnetComponents[5]}/${vnetComponents[6]}/${vnetComponents[7]}/${vnetComponents[8]}'

module dnsZone 'dnsZone.bicep' = {
  name: '${containerenvironment.name}-dns'
  params: {
    resourceTags: resourceTags
    registrationEnabled: false
    zoneName: containerenvironment.properties.defaultDomain
    vnetName: 'cae'
    vnetId: vnetId
  }
}

resource helloApp 'Microsoft.App/containerApps@2023-05-02-preview' = {
  name: 'hello'
  location: location
  properties: {
    managedEnvironmentId: containerenvironment.id
    environmentId: containerenvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        exposedPort: 0
        transport: 'Auto'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        allowInsecure: false
      }
    }
    template: {
      revisionSuffix: ''
      containers: [
        {
          image: 'mcr.microsoft.com/k8se/quickstart:latest'
          name: 'simple-hello-world-container'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 10
      }
    }
  }
  identity: {
    type: 'None'
  }
}

module aRecord 'dnsRecord.bicep' = {
  name: helloApp.name
  params: {
    ipAddress: containerenvironment.properties.staticIp
    recordName: helloApp.name
    zone: containerenvironment.properties.defaultDomain
  }
  dependsOn: [
    dnsZone
  ]
}

@description('Id of Container Environment')
output id string              = containerenvironment.id
@description('The static IP of the environment.')
output staticIp string        = containerenvironment.properties.staticIp
@description('The default domain.')
output defaultDomain string   = containerenvironment.properties.defaultDomain
@description('Verification id for creating DNS records')
output verificationId string  = containerenvironment.properties.customDomainConfiguration.customDomainVerificationId
