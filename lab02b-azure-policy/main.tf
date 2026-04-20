resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags = {
    (var.tag_name) = var.tag_value
  }
}

data "azurerm_policy_definition_built_in" "require_tag" {
  display_name = "Require a tag and its value on resource groups"
}

resource "azurerm_resource_group_policy_assignment" "require_cost_center" {
  name                 = "Require Cost Center tag and its value on resources"
  description          = "Require Cost Center tag and its value on all resources in the resource group"
  enforce              = true
  policy_definition_id = data.azurerm_policy_definition_built_in.require_tag.id
  resource_group_id    = azurerm_resource_group.rg.id

  parameters = jsonencode({
    tagName = {
      value = var.tag_name
    }
    tagValue = {
      value = var.tag_value
    }
  })
}

data "azurerm_policy_definition_built_in" "inherit_tag" {
  display_name = "Inherit a tag from the resource group if missing"
}

resource "azurerm_resource_group_policy_assignment" "inherit_tag_assignment" {
  name                 = "Inherit the Cost Center tag and its value 000"
  description          = "Inherit the Cost Center tag and its value 000 from the resource group if missing"
  enforce              = true
  resource_group_id    = azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition_built_in.inherit_tag.id
  location             = azurerm_resource_group.rg.location

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    tagName = {
      value = var.tag_name
    }
  })
}

resource "azurerm_resource_group_policy_remediation" "remediation" {
  name                 = "remediation-inherit-tag"
  resource_group_id    = azurerm_resource_group.rg.id
  policy_assignment_id = azurerm_resource_group_policy_assignment.inherit_tag_assignment.id
}

resource "azurerm_management_lock" "rg_lock" {
  name       = "rg-lock"
  scope      = azurerm_resource_group.rg.id
  lock_level = "CanNotDelete"
}
