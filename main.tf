provider "azurerm" {
version = "=2.0.0"
features {}
}
resource "azurerm_resource_group" "aks-azurefw" {
  name     = "AzureFWRG"
  location = "East US 2"
}

resource "azurerm_virtual_network" "hubvnet" {
  name                = "hubvnet"
  address_space       = ["10.230.0.0/16"]
  location            = azurerm_resource_group.aks-azurefw.location
  resource_group_name = azurerm_resource_group.aks-azurefw.name
}

resource "azurerm_subnet" "azurefirewallsubnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.aks-azurefw.name
  virtual_network_name = azurerm_virtual_network.hubvnet.name
  address_prefix       = "10.230.1.0/24"
}

resource "azurerm_subnet" "akssubnet" {
  name                 = "AKSsubnet"
  resource_group_name  = azurerm_resource_group.aks-azurefw.name
  virtual_network_name = azurerm_virtual_network.hubvnet.name
  address_prefix       = "10.230.2.0/24"
}

resource "azurerm_subnet" "azuresbcloudsvc" {
  name                 = "springboot-service-subnet"
  resource_group_name  = azurerm_resource_group.aks-azurefw.name
  virtual_network_name = azurerm_virtual_network.hubvnet.name
  address_prefix       = "10.230.3.0/24"
}

resource "azurerm_subnet" "azuresbcloudapps" {
  name                 = "springboot-apps-subnet"
  resource_group_name  = azurerm_resource_group.aks-azurefw.name
  virtual_network_name = azurerm_virtual_network.hubvnet.name
  address_prefix       = "10.230.4.0/24"
}

resource "azurerm_public_ip" "azurefwpip" {
  name                = "azurefwpip"
  location            = azurerm_resource_group.aks-azurefw.location
  resource_group_name = azurerm_resource_group.aks-azurefw.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "azfw" {
  name                = "egressfirewall"
  location            = azurerm_resource_group.aks-azurefw.location
  resource_group_name = azurerm_resource_group.aks-azurefw.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.azurefirewallsubnet.id
    public_ip_address_id = azurerm_public_ip.azurefwpip.id
  }
}

resource "azurerm_route_table" "aks-rt" {
  name                          = "aksfwrt"
  location                      = azurerm_resource_group.aks-azurefw.location
  resource_group_name           = azurerm_resource_group.aks-azurefw.name
  disable_bgp_route_propagation = false

  route {
    name           = "aksfwrn"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.azfw.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "aks-default-route" {
  subnet_id      = azurerm_subnet.akssubnet.id
  route_table_id = azurerm_route_table.aks-rt.id
}

resource "azurerm_firewall_application_rule_collection" "aks_servicetag" {
  name                = "AzureGlobalRequiredApplicationServiceTag"
  azure_firewall_name = azurerm_firewall.azfw.name
  resource_group_name = azurerm_resource_group.aks-azurefw.name
  priority            = 150
  action              = "Allow"

  rule {
    name = "AKS_ServiceTag"

    source_addresses = [
      "*",
    ]

    fqdn_tags = [      
       
       "AzureKubernetesService",
       
    ]
  }
}

resource "azurerm_firewall_application_rule_collection" "microsoft_crl" {
  name                = "Microsoft_CRL_rules"
  azure_firewall_name = azurerm_firewall.azfw.name
  resource_group_name = azurerm_resource_group.aks-azurefw.name
  priority            = 200
  action              = "Allow"

  rule {
    name = "Required CRL Rules"

    source_addresses = [
      "*",
    ]

    target_fqdns = [      
       
       "crl.microsoft.com",
       "mscrl.microsoft.com",
       "crl3.digicert.com",
       "ocsp.digicert.com"
       
    ]

    protocol {
      port = "80"
      type = "Http"
    }
  }
}

resource "azurerm_firewall_application_rule_collection" "ubuntu_libs" {
  name                = "ubuntu_libaries_rules"
  azure_firewall_name = azurerm_firewall.azfw.name
  resource_group_name = azurerm_resource_group.aks-azurefw.name
  priority            = 250
  action              = "Allow"

  rule {
    name = "Ubuntu Libraries"

    source_addresses = [
      "*",
    ]

    target_fqdns = [      
       
       "api.snapcraft.io",
       "motd.ubuntu.com",       
    ]

    protocol {
      port = "443"
      type = "Https"
    }
  }
}

resource "azurerm_firewall_network_rule_collection" "aks_netrules_udp" {
  name                = "AKS_network_udp_rules"
  azure_firewall_name = azurerm_firewall.azfw.name
  resource_group_name = azurerm_resource_group.aks-azurefw.name
  priority            = 200
  action              = "Allow"

  rule {
    name = "AzureGlobalRequiredNetwork_UDP"

    source_addresses = [
      "*",
    ]

    destination_ports = [
      "1194",
      "53",  
    ]

    destination_addresses = [
      "AzureCloud.EastUS",
      "AzureCloud.EastUS2"
    ]

    protocols = [
      "UDP",
    ]
  }

  rule {
    name = "AzureGlobalRequired_NTP"

    source_addresses = [
      "*",
    ]

    destination_ports = [
      "123",
    ]

    destination_addresses = [
      "*",
    ]

    protocols = [
      "UDP",
    ]
  }
}

resource "azurerm_firewall_network_rule_collection" "aks_netrules_tcp" {
  name                = "AKS_network_tcp_rules"
  azure_firewall_name = azurerm_firewall.azfw.name
  resource_group_name = azurerm_resource_group.aks-azurefw.name
  priority            = 100
  action              = "Allow"

  rule {
    name = "AzureGlobalRequiredNetwork_TCP"

    source_addresses = [
      "*",
    ]

    destination_ports = [
      "9000",
      "443",  
    ]

    destination_addresses = [
      "AzureCloud.eastus2",
      "AzureCloud.eastus",
    ]

    protocols = [
      "TCP",
    ]
  }
  
}

resource "azurerm_firewall_network_rule_collection" "spring_cloud_tcp" {
  name                = "spring_cloud_network_tcp_rules"
  azure_firewall_name = azurerm_firewall.azfw.name
  resource_group_name = azurerm_resource_group.aks-azurefw.name
  priority            = 300
  action              = "Allow"

  rule {
    name = "AzureSpringCloudStorageNetwork"

    source_addresses = [
      "*",
    ]

    destination_ports = [  
      "445",  
    ]

    destination_addresses = [
      "Storage",
    ]

    protocols = [
      "TCP",
    ]
  }
  
}