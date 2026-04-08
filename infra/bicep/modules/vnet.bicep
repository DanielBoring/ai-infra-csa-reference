// ---------------------------------------------------------------------------
// Module: Virtual Network + Subnets (Private Networking)
// Uses: avm/res/network/virtual-network
// Deployed only when enablePrivateNetworking = true
// ---------------------------------------------------------------------------

@description('Name of the VNet.')
param name string

@description('Azure region.')
param location string

@description('Resource tags.')
param tags object = {}

@description('VNet address prefix.')
param addressPrefix string = '10.0.0.0/16'

@description('ACA subnet prefix (minimum /23).')
param acaSubnetPrefix string = '10.0.0.0/23'

@description('Private Endpoint subnet prefix.')
param peSubnetPrefix string = '10.0.2.0/24'

module vnet 'br/public:avm/res/network/virtual-network:0.5.0' = {
  name: '${name}-deploy'
  params: {
    name: name
    location: location
    tags: tags
    addressPrefixes: [addressPrefix]
    subnets: [
      {
        name: 'snet-aca'
        addressPrefix: acaSubnetPrefix
        delegation: 'Microsoft.App/environments'
      }
      {
        name: 'snet-pe'
        addressPrefix: peSubnetPrefix
      }
    ]
  }
}

output resourceId string = vnet.outputs.resourceId
output name string = vnet.outputs.name
output acaSubnetId string = vnet.outputs.subnetResourceIds[0]
output peSubnetId string = vnet.outputs.subnetResourceIds[1]
