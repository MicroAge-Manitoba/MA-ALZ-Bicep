@description('The name of the Virtual Network to Create')
param virtualNetworkName string

@description('The address range of the new VNET in CIDR format')
param virtualNetworkAddressRange string

@description('The name of the subnet created in the new VNET')
param subnetName string

@description('The address range of the subnet created in the new VNET')
param subnetRange string

@description('Location for all resources.')
param location string

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: '${virtualNetworkName}-default-nsg'
  location: location
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressRange
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetRange
          networkSecurityGroup: {
            id: networkSecurityGroup.id
            location: location
            properties: {
              flushConnection: false
              securityRules: [
              ]
            }
          }
        }
      }
    ]
  }
  dependsOn: [
    networkSecurityGroup
  ]
}
