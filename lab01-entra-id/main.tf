data "azuread_domains" "current" {
  only_initial = true
}

data "azuread_client_config" "current" {}

resource "random_password" "user1_password" {
  length  = 16
  special = true
}

resource "azuread_user" "user1" {
  user_principal_name = "az104-user1@${data.azuread_domains.current.domains.0.domain_name}"
  display_name        = "az104-user1"

  password              = random_password.user1_password.result
  force_password_change = true
  account_enabled       = true

  job_title      = "IT Lab Administrator"
  department     = "IT"
  usage_location = "US"
}

output "user1_password" {
  value     = random_password.user1_password.result
  sensitive = true
}


resource "azuread_invitation" "user2_invitation" {
  user_display_name  = var.guest_user_name
  user_email_address = var.guest_user_email
  redirect_url       = "https://myapplications.microsoft.com/?tenantid=${data.azuread_client_config.current.tenant_id}"

  message {
    body = "Welcome to Azure and our group project"
  }
}

resource "azuread_group" "group" {
  display_name     = "IT Lab Administrators"
  description      = "Administrators that manage the IT lab"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true

  members = [
    azuread_user.user1.object_id,
    azuread_invitation.user2_invitation.user_id
  ]
}
