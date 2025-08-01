// Parameters expected from YAML Pipeline
// @description('Deployment location for resources in this deployment')
// param environmentName string // ex: dev or prod
@description('Deployment location for resources in this deployment')
param deploymentLocation string // ex: westeurope
// @description('App ID of the principal ID of the service connection from Azure DevOps')
// param azureResourceManagerServiceConnectionAppId string
//param allowedOrigins array = []

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
    softDeleteRetentionInDays: 7
    tenantId: subscription().tenantId
  }
}

resource functionAppStorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: '${uniqueString(subscription().subscriptionId, resourceGroup().id)}stg'
  location: deploymentLocation
  tags: { RESSOURCE_PURPOSE: 'Storage' }
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    accessTier: 'Hot'
    allowedCopyScope: 'AAD'
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: true
    defaultToOAuthAuthentication: false
    dnsEndpointType: 'Standard'
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    isHnsEnabled: true
    isLocalUserEnabled: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    publicNetworkAccess: 'Enabled'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}
