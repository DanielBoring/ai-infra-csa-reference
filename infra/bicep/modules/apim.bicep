// ---------------------------------------------------------------------------
// Module: API Management
// Uses: avm/res/api-management/service
// Decision: Consumption tier default (ADR-005)
// ---------------------------------------------------------------------------

@description('Name of the APIM instance.')
param name string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object = {}

@description('APIM SKU name.')
@allowed(['Consumption', 'Developer', 'StandardV2'])
param skuName string = 'Consumption'

@description('Publisher email address (required by APIM).')
param publisherEmail string

@description('Publisher display name.')
param publisherName string = 'AI Infra CSA Reference'

@description('Managed Identity resource ID.')
param managedIdentityId string = ''

@description('Whether to use the stub backend.')
param useStub bool = true

@description('Real AI Foundry endpoint URL (used when useStub=false).')
param aiFoundryEndpoint string = ''

var skuCapacity = skuName == 'Consumption' ? 0 : 1

module service 'br/public:avm/res/api-management/service:0.14.1' = {
  name: '${name}-deploy'
  params: {
    name: name
    location: location
    tags: tags
    sku: skuName
    skuCapacity: skuCapacity
    publisherEmail: publisherEmail
    publisherName: publisherName
    managedIdentities: !empty(managedIdentityId) ? {
      userAssignedResourceIds: [managedIdentityId]
    } : null
    apis: [
      {
        name: 'chat-api'
        displayName: 'Chat API'
        path: 'chat'
        protocols: ['https']
        serviceUrl: useStub ? '' : aiFoundryEndpoint
        apiType: 'http'
      }
    ]
  }
}

output resourceId string = service.outputs.resourceId
output name string = service.outputs.name
output gatewayUrl string = 'https://${name}.azure-api.net'
