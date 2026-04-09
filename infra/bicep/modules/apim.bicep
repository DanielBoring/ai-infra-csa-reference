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

// ---------------------------------------------------------------------------
// Explicit resources: operation + stub policy (AVM module does not support
// inline operations, so we add them as child resources after the service
// module has finished deploying).
// ---------------------------------------------------------------------------

resource apimService 'Microsoft.ApiManagement/service@2022-08-01' existing = {
  name: name
}

// Re-declare the chat-api so we can set subscriptionRequired: false, which
// allows smoke tests to call the API without a subscription key in dev/CI.
resource chatApi 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  parent: apimService
  name: 'chat-api'
  dependsOn: [service]
  properties: {
    displayName: 'Chat API'
    path: 'chat'
    protocols: ['https']
    serviceUrl: useStub ? '' : aiFoundryEndpoint
    subscriptionRequired: false
  }
}

// POST /completions operation
resource postCompletionsOperation 'Microsoft.ApiManagement/service/apis/operations@2022-08-01' = {
  parent: chatApi
  name: 'post-completions'
  properties: {
    displayName: 'Create Chat Completion'
    method: 'POST'
    urlTemplate: '/completions'
    description: 'Creates a chat completion. Returns a mock response when useStub=true.'
  }
}

// Stub backend policy — returns a valid OpenAI-compatible mock 200 response
// without hitting any real backend. Applied only when useStub=true (i.e., when
// no real AI Foundry endpoint is configured).
resource postCompletionsPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2022-08-01' = if (useStub) {
  parent: postCompletionsOperation
  name: 'policy'
  properties: {
    format: 'xml'
    value: loadTextContent('../../apim/policies/stub-backend-policy.xml')
  }
}

output resourceId string = service.outputs.resourceId
output name string = service.outputs.name
output gatewayUrl string = 'https://${name}.azure-api.net'
