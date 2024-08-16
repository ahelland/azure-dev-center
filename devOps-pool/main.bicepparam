using './main.bicep'

param resourceTags = {
    IaC: 'Bicep'
    Source: 'GitHub'  
}

param location = 'northeurope'
param azdoOrganization = 'Contoso'
param devOpsSPId = 'guid'
