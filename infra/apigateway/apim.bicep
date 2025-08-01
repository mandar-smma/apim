// Parameters expected from Main Bicep file
@description('Deployment location for resources in this deployment')
param location string // ex: westeurope
@description('Apim publisher email')
param publisherEmail string
@description('Apim publisher name')
param publisherName string
@description('apim name')
param name string
@description('app insights name for apim')
param applicationInsightsName string


resource apimService 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: name
  location: location
  tags: { RESSOURCE_PURPOSE: 'APIM' }
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  name: applicationInsightsName
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = if (!empty(applicationInsightsName)) {
  name: 'app-insights-logger'
  parent: apimService
  properties: {
    credentials: {
      instrumentationKey: applicationInsights.properties.InstrumentationKey
    }
    description: 'Logger to Azure Application Insights'
    isBuffered: false
    loggerType: 'applicationInsights'
    resourceId: applicationInsights.id
  }
}

output apimServiceName string = apimService.name
