resource "azuread_group" "helpdesk" {
  display_name     = var.helpdesk_group_name
  security_enabled = true
}

resource "azurerm_management_group" "mg1" {
  display_name = var.mgmt_group_name
  name         = var.mgmt_group_id
}

resource "azurerm_role_assignment" "vm_contributor" {
  scope                = azurerm_management_group.mg1.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azuread_group.helpdesk.object_id
}

data "azurerm_role_definition" "parent" {
  name = "Support Request Contributor"
}

resource "azurerm_role_definition" "custom_support" {
  name        = "Custom Support Request"
  scope       = azurerm_management_group.mg1.id
  description = "A custom contributor role for support requests."

  permissions {
    actions = data.azurerm_role_definition.parent.permissions[0].actions
    not_actions = concat(data.azurerm_role_definition.parent.permissions[0].not_actions, [
      "Microsoft.Support/register/action"
    ])
    data_actions = data.azurerm_role_definition.parent.permissions[0].data_actions
    not_data_actions = data.azurerm_role_definition.parent.permissions[0].not_data_actions
  }

  assignable_scopes = [
    azurerm_management_group.mg1.id
  ]
}
