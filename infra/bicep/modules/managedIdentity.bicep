// ---------------------------------------------------------------------------
// Module: User-Assigned Managed Identity
// Uses: avm/res/managed-identity/user-assigned-identity
// ---------------------------------------------------------------------------

@description('Name of the Managed Identity.')
param name string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object = {}

module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: '${name}-deploy'
  params: {
    name: name
    location: location
    tags: tags
  }
}

output resourceId string = identity.outputs.resourceId
output principalId string = identity.outputs.principalId
output clientId string = identity.outputs.clientId
output name string = identity.outputs.name
