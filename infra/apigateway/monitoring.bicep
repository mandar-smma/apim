@description('resource group for the deployment')
param resourceGroupName string

@description('storage account for the deployment')
param storageAccountName string

resource functionAppStorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing= {
  name: storageAccountName
 
}
