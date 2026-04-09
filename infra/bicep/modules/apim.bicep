// ---------------------------------------------------------------------------
// Module: API Management
// Uses: Microsoft.ApiManagement/service (ARM resource)
// Decision: Consumption SKU for cost-effective API gateway (ADR-005)
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

@description('APIM publisher email.')
param publisherEmail string

@description('APIM publisher name.')
param publisherName string

@description('User-Assigned Managed Identity resource ID.')
param managedIdentityId string

@description('When true, use the stub backend policy instead of a real AI Foundry endpoint.')
param useStub bool = true

@description('Real Azure AI Foundry endpoint URL. Only used when useStub is false.')
param aiFoundryEndpoint string = ''

// ---------------------------------------------------------------------------
// APIM Service
// ---------------------------------------------------------------------------

resource apimService 'Microsoft.ApiManagement/service@2023-09-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    capacity: skuName == 'Consumption' ? 0 : 1
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

// ---------------------------------------------------------------------------
// API: OpenAI-compatible Completions
// ---------------------------------------------------------------------------

resource completionsApi 'Microsoft.ApiManagement/service/apis@2023-09-01-preview' = {
  parent: apimService
  name: 'openai-completions'
  properties: {
    displayName: 'OpenAI Completions'
    description: 'OpenAI-compatible Chat Completions API backed by Azure AI Foundry or stub.'
    path: 'openai'
    protocols: ['https']
    subscriptionRequired: false
    serviceUrl: useStub ? null : aiFoundryEndpoint
  }
}

// ---------------------------------------------------------------------------
// Operation: POST /v1/chat/completions
// ---------------------------------------------------------------------------

resource postCompletionsOperation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: completionsApi
  name: 'post-chat-completions'
  properties: {
    displayName: 'Chat Completions'
    method: 'POST'
    urlTemplate: '/v1/chat/completions'
    description: 'Submit a chat completion request.'
  }
}

// ---------------------------------------------------------------------------
// Policy: Stub backend — returns a valid OpenAI-compatible mock 200 response.
// loadTextContent path is relative to this module file:
//   infra/bicep/modules/apim.bicep
// The policy file lives at apim/policies/stub-backend-policy.xml (repo root).
// Three levels up (modules/ -> bicep/ -> infra/ -> repo root) gives ../../../
// ---------------------------------------------------------------------------

resource postCompletionsPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-09-01-preview' = {
  parent: postCompletionsOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('../../../apim/policies/stub-backend-policy.xml')
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output resourceId string = apimService.id
output name string = apimService.name
output gatewayUrl string = apimService.properties.gatewayUrl
