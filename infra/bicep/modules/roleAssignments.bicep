// ---------------------------------------------------------------------------
// Module: Role Assignments
// Uses: avm/ptn/authorization/resource-role-assignment
// Decision: Least-privilege RBAC (ADR-003)
// ---------------------------------------------------------------------------

@description('Principal ID of the Managed Identity to assign roles to.')
param managedIdentityPrincipalId string

@description('Name of the Key Vault (for scoped role assignment).')
param keyVaultName string

@description('Name of the APIM instance (for scoped role assignment).')
param apimName string

// Key Vault Secrets User — allows the MI to read secrets
resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, managedIdentityPrincipalId, '4633458b-17de-408a-b874-0445c86b69e6')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// API Management Service Reader — allows MI to discover APIM
resource apimRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(apimResource.id, managedIdentityPrincipalId, 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
  scope: apimResource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7') // Reader
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Reference existing resources for scoping
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource apimResource 'Microsoft.ApiManagement/service@2023-09-01-preview' existing = {
  name: apimName
}
