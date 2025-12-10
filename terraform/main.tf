#--------------------------
# Providers
#--------------------------
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">=2.0.0"
    }
  }
  required_version = ">=1.3.0"
}

provider "azurerm" {
  features {}
  # use_oidc = true
  subscription_id = "02a44fee-b200-4cf9-b042-9bd4aa3bebe6"
tenant_id = "63b9a1c1-375c-42cf-9c63-dc3798c7ae5e"
}

provider "azuread" {}

#--------------------------
# Resource Group
#--------------------------
resource "azurerm_resource_group" "rg" {
  name     = "rg-demo"
  location = "Canada Central"
}

#--------------------------
# Storage Accounts
#--------------------------
resource "azurerm_storage_account" "sa1" {
  name                     = "stordemo001"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_account" "sa2" {
  name                     = "stordemo002"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

#--------------------------
# Azure Container Registry
#--------------------------
resource "azurerm_container_registry" "acr" {
  name                = "democontaineracr001"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

#--------------------------
# Container App Environment
#--------------------------
resource "azurerm_container_app_environment" "env" {
  name                = "demo-env"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

#--------------------------
# Container App
#--------------------------
resource "azurerm_container_app" "app" {
  name                         = "demo-app"
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.env.id
  revision_mode                = "Single"

  template {
    container {
      name   = "demo"
      image  = "${azurerm_container_registry.acr.login_server}/mybot:v7"
      cpu    = 0.5
      memory = "1.0Gi"

      env {
        name  = "STORAGE_ACCOUNT1"
        value = azurerm_storage_account.sa1.name
      }

      env {
        name  = "STORAGE_ACCOUNT2"
        value = azurerm_storage_account.sa2.name
      }
    }
  }
}

#--------------------------
# Azure AD Application (Bot App)
#--------------------------
resource "azuread_application" "bot_app" {
  display_name = "demo-bot-app"
}

resource "azuread_application_password" "bot_app_password" {
  application_id = azuread_application.bot_app.id
  display_name   = "demo-bot-app-password"
  end_date       = "2026-12-10T23:59:59Z"
}


#--------------------------
# Bot Channels Registration
#--------------------------
resource "azurerm_bot_channels_registration" "bot" {
  name                = "demo-bot"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "F0"

  microsoft_app_id = azuread_application.bot_app.id

  depends_on = [azuread_application_password.bot_app_password]
}

#--------------------------
# Outputs
#--------------------------
output "bot_app_id" {
  value = azuread_application.bot_app.id  # v1.x syntax
}
output "bot_app_password" {
  value     = azuread_application_password.bot_app_password.value
  sensitive = true
}

output "container_image" {
  value = "${azurerm_container_registry.acr.login_server}/mybot:v7"
}
