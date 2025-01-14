@description('The name of the administrator account of the new VM and domain')
param adminUsername string

@description('The password for the administrator account of the new VM and domain')
@secure()
param adminPassword string

@description('The FQDN of the Active Directory Domain to be created')
param domainName string

@description('Size of the VM for the controller')
param vmSize string = 'Standard_D2s_v3'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Virtual machine name.')
@maxLength(15)
param virtualMachineName string = 'adVM'

@description('Virtual network name.')
param virtualNetworkName string = 'adVNET'

@description('Virtual network address range.')
param virtualNetworkAddressRange string = '10.0.0.0/16'

@description('Network interface name.')
param networkInterfaceName string = 'adNic'

@description('Private IP address.')
param privateIPAddress string = '10.0.0.4'

@description('Subnet name.')
param subnetName string = 'adSubnet'

@description('Subnet IP range.')
param subnetRange string = '10.0.0.0/24'


module VNet 'nestedtemplates/vnet.bicep' = {
  scope: resourceGroup()
  name: 'VNet'
  params: {
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressRange: virtualNetworkAddressRange
    subnetName: subnetName
    subnetRange: subnetRange
    location: location
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: privateIPAddress
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
          }
        }
      }
    ]
  }
  dependsOn: [
    VNet
  ]
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-08-01' = {
  name: virtualMachineName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: virtualMachineName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        name: '${virtualMachineName}_OSDisk'
        caching: 'ReadOnly'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
  }
  dependsOn: [
    networkInterface
  ]
}

resource createADForest 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  parent: virtualMachine
  name: 'CreateADForest'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.19'
    autoUpgradeMinorVersion: true
    settings: {
      ModulesUrl: 'https://github.com/MicroAge-Manitoba/MA-ALZ-Bicep/blob/main/infra-as-code/bicep/modules/active-directory-new-domain/DSC/CreateADPDC.zip?raw=true'
      ConfigurationFunction: 'CreateADPDC.ps1\\CreateADPDC'
      Properties: {
        DomainName: domainName
        AdminCreds: {
          UserName: adminUsername
          Password: 'PrivateSettingsRef:AdminPassword'
        }
      }
    }
    protectedSettings: {
      Items: {
        AdminPassword: adminPassword
      }
    }
  }
}

module updateVNetDNS 'nestedtemplates/vnet-with-dns-server.bicep' = {
  scope: resourceGroup()
  name: 'UpdateVNetDNS'
  params: {
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressRange: virtualNetworkAddressRange
    subnetName: subnetName
    subnetRange: subnetRange
    DNSServerAddress: [
      privateIPAddress
    ]
    location: location
  }
  dependsOn: [
    createADForest
  ]
}
