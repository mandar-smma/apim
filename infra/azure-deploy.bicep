// Parameters expected from YAML Pipeline
// @description('Deployment location for resources in this deployment')
// param environmentName string // ex: dev or prod
@description('Deployment location for resources in this deployment')
param deploymentLocation string // ex: westeurope
// @description('App ID of the principal ID of the service connection from Azure DevOps')
// param azureResourceManagerServiceConnectionAppId string
param allowedOrigins array = []

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

// File share in storage account used for function app
resource functionAppFileService 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' = {
  name: 'default'
  parent: functionAppStorageAccount
}
resource functionAppFileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = {
  parent: functionAppFileService
  name: '${uniqueString(subscription().subscriptionId, resourceGroup().id)}fs'
  properties: {
    accessTier: 'Hot'
  }
}

// Hosting Plan
resource functionAppHostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${uniqueString(subscription().subscriptionId, resourceGroup().id)}hpl'
  location: deploymentLocation
  kind: 'linux'
  properties: {
    zoneRedundant: false
    reserved: true
  }
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}


// Application Insight
resource functionAppApplicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${uniqueString(subscription().subscriptionId, resourceGroup().id)}ain'
  location: deploymentLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}


// Function app
var functionAppName = '${uniqueString(subscription().subscriptionId, resourceGroup().id)}fun'
resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: deploymentLocation
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    hostNameSslStates: [
      {
        name: '${functionAppName}.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Standard'
      }
      {
        name: '${functionAppName}.scm.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Repository'
      }
    ]
    
    serverFarmId: functionAppHostingPlan.id
    reserved: true
    vnetRouteAllEnabled: true
    vnetImagePullEnabled: false
    vnetContentShareEnabled: false
    siteConfig: {
      linuxFxVersion: 'Python|3.12'
      acrUseManagedIdentityCreds: false
      alwaysOn: false
      http20Enabled: false
      functionAppScaleLimit: 0
      appSettings: [
       
        {
          name: 'WEBSITE_CONTENTOVERVNET'
          value: '1'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionAppStorageAccount.name};AccountKey=${functionAppStorageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionAppStorageAccount.name};AccountKey=${functionAppStorageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: functionAppFileShare.name
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: functionAppApplicationInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: functionAppApplicationInsights.properties.ConnectionString
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
      ]
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      cors: {
        allowedOrigins: union([ 'https://portal.azure.com', 'https://ms.portal.azure.com' ], allowedOrigins)
      }
    }
    scmSiteAlsoStopped: false
    clientAffinityEnabled: false
    //clientCertEnabled: false
    //clientCertMode: 'Required'
    hostNamesDisabled: false
    containerSize: 1536
    dailyMemoryTimeQuota: 0
    httpsOnly: true
    redundancyMode: 'None'
    publicNetworkAccess: 'Enabled'
    //storageAccountRequired: false
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
}

// Dot no allow FTP as deployment should not be done that way
resource functionAppCredentialPolicyFtp 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2022-03-01' = {
  parent: functionApp
  name: 'ftp'
  #disable-next-line BCP187
  location: deploymentLocation
  properties: {
    allow: false
  }
}

// Do not allow SCM as this should not be exposed in production
resource functionAppCredentialPolicyScm 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2022-03-01' = {
  parent: functionApp
  name: 'scm'
  #disable-next-line BCP187
  location: deploymentLocation
  properties: {
    allow: false
  }
}

// Output function app name
output functionAppName string = functionApp.name
