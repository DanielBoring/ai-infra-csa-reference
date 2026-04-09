// ---------------------------------------------------------------------------
// Module: Container App (Chatbot)
// Uses: avm/res/app/container-app
// ---------------------------------------------------------------------------

@description('Name of the Container App.')
param name string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object = {}

@description('ACA Environment resource ID.')
param environmentId string

@description('User-Assigned Managed Identity resource ID.')
param managedIdentityId string

@description('Managed Identity client ID (for AZURE_CLIENT_ID env var).')
param managedIdentityClientId string

@description('Container image to deploy.')
param containerImage string

@description('Minimum replicas (0 = scale to zero).')
@minValue(0)
param minReplicas int = 0

@description('Maximum replicas.')
@minValue(1)
param maxReplicas int = 5

@description('APIM gateway URL for the app to call.')
param apimGatewayUrl string

@description('Application Insights connection string.')
param appInsightsConnectionString string

module app 'br/public:avm/res/app/container-app:0.11.0' = {
  name: '${name}-deploy'
  params: {
    name: name
    location: location
    tags: tags
    environmentResourceId: environmentId
    managedIdentities: {
      userAssignedResourceIds: [managedIdentityId]
    }
    containers: [
      {
        name: 'chatbot'
        image: containerImage
        resources: {
          cpu: '0.25'
          memory: '0.5Gi'
        }
        env: [
          { name: 'APIM_ENDPOINT', value: apimGatewayUrl }
          { name: 'AZURE_CLIENT_ID', value: managedIdentityClientId }
          { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsConnectionString }
          { name: 'NODE_ENV', value: 'production' }
          { name: 'PORT', value: '3000' }
        ]
      }
    ]
    scaleMinReplicas: minReplicas
    scaleMaxReplicas: maxReplicas
    scaleRules: [
      {
        name: 'http-scaling'
        http: {
          metadata: {
            concurrentRequests: '10'
          }
        }
      }
    ]
    disableIngress: false
    ingressTargetPort: 3000
    ingressTransport: 'http'
    ingressExternal: true
  }
}

output resourceId string = app.outputs.resourceId
output name string = app.outputs.name
output fqdn string = app.outputs.fqdn
