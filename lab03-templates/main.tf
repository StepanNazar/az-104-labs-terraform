resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_managed_disk" "disk1" {
  name                 = var.disk1_name
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32
}


resource "azurerm_resource_group_template_deployment" "task2" {
  name                = "task2"
  resource_group_name = azurerm_resource_group.rg.name
  deployment_mode     = "Incremental"
  parameters_content = jsonencode({
    "disk_name" = {
      value = var.disk2_name
    }
  })
  template_content = file("${path.module}/template.json")
}

# Identity for Deployment Scripts
resource "azurerm_user_assigned_identity" "script_identity" {
  name                = "az104-script-identity"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "script_contributor" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.script_identity.principal_id
}

resource "azurerm_resource_deployment_script_azure_power_shell" "task3" {
  name                = "task3"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  version             = "8.3"
  retention_interval  = "P1D"
  cleanup_preference  = "OnSuccess"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.script_identity.id]
  }

  script_content = <<EOF
$template = @'
${file("${path.module}/template.json")}
'@
$template | Out-File -FilePath template.json -Encoding utf8

$parameters = @'
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "disk_name": {
            "value": "az104-disk3"
        }
    }
}
'@
$parameters | Out-File -FilePath parameters.json -Encoding utf8

New-AzResourceGroupDeployment -ResourceGroupName ${azurerm_resource_group.rg.name} -TemplateFile template.json -TemplateParameterFile parameters.json
Get-AzDisk -ResourceGroupName ${azurerm_resource_group.rg.name} | Where-Object { $_.Name -eq "az104-disk3" } | Select-Object Name, ResourceGroupName, Location, DiskSizeGb, ProvisioningState | Format-Table
EOF

  depends_on = [azurerm_role_assignment.script_contributor]
}

resource "azurerm_resource_deployment_script_azure_cli" "task4" {
  name                = "deploy-disk4-cli"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  version             = "2.40.0"
  retention_interval  = "P1D"
  cleanup_preference  = "OnSuccess"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.script_identity.id]
  }

  script_content = <<-EOT
    cat <<'EOF' > template.json
    ${file("${path.module}/template.json")}
    EOF

    cat <<'EOF' > parameters.json
    {
        "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
        "contentVersion": "1.0.0.0",
        "parameters": {
            "disk_name": {
                "value": "az104-disk4"
            }
        }
    }
    EOF

    az deployment group create --resource-group ${azurerm_resource_group.rg.name} --template-file template.json --parameters parameters.json
    az disk list --resource-group ${azurerm_resource_group.rg.name} --query "[?name=='az104-disk4']" --output table
  EOT

  depends_on = [azurerm_role_assignment.script_contributor]
}

resource "azurerm_resource_deployment_script_azure_cli" "task5" {
  name                = "deploy-disk5-bicep"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  version             = "2.40.0"
  retention_interval  = "P1D"
  cleanup_preference  = "OnSuccess"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.script_identity.id]
  }

  script_content = <<-EOT
    cat <<'BICEP_EOF' > disk.bicep
${file("${path.module}/azuredeploydisk.bicep")}
BICEP_EOF
    az deployment group create --resource-group ${azurerm_resource_group.rg.name} --template-file disk.bicep
    az disk list --resource-group ${azurerm_resource_group.rg.name} --query "[?name=='az104-disk5']" --output table
  EOT

  depends_on = [azurerm_role_assignment.script_contributor]
}
