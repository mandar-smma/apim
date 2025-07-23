// Parameters expected from YAML Pipeline
@description('Deployment location for resources in this deployment')
param environmentName string // ex: dev or prod
@description('Deployment location for resources in this deployment')
param deploymentLocation string // ex: westeurope
@description('App ID of the principal ID of the service connection from Azure DevOps')
param azureResourceManagerServiceConnectionAppId string


// Key vault
resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: '${uniqueString(subscription().subscriptionId, resourceGroup().id)}kv'
  location: deploymentLocation
  tags: { RESSOURCE_PURPOSE: 'Security' }
  properties: {
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableRbacAuthorization: true
    enableSoftDelete: true
    publicNetworkAccess: 'Enabled'
    sku: {
      name: 'standard'
      family: 'A'
    }
    softDeleteRetentionInDays: 14
    tenantId: subscription().tenantId
  }
}
