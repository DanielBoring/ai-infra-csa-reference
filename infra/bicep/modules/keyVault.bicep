// ---------------------------------------------------------------------------
// Module: Key Vault
// Uses: avm/res/key-vault/vault
// Decision: RBAC access model (ADR-007)
// ---------------------------------------------------------------------------

@description('Name of the Key Vault. Must be globally unique, 3-24 chars, alphanumeric.')
param name string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object = {}

module vault 'br/public:avm/res/key-vault/vault:0.11.0' = {
  name: '${name}-deploy'
  params: {
    name: name
    location: location
    tags: tags
    enableRbacAuthorization: true
    enablePurgeProtection: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    sku: 'standard'
  }
}

output resourceId string = vault.outputs.resourceId
output name string = vault.outputs.name
output uri string = vault.outputs.uri
