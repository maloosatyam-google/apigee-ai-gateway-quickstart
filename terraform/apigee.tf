locals {
  is_payg        = var.billing_type == "PAYG"
  envgroups      = toset([for name, e in var.environments : coalesce(e.envgroup, "${name}-group")])
  env_group_of   = { for name, e in var.environments : name => coalesce(e.envgroup, "${name}-group") }
  analytics_envs = { for name, e in var.environments : name => e if local.is_payg && e.analytics }
  primary_env    = keys(var.environments)[0]
}

resource "google_apigee_organization" "org" {
  project_id          = var.project_id
  display_name        = var.project_id
  description         = "Apigee X (${var.billing_type}) AI Gateway Quickstart, managed by Terraform"
  runtime_type        = "CLOUD"
  billing_type        = var.billing_type
  disable_vpc_peering = true
  analytics_region    = var.region

  depends_on = [google_project_service.apis]
}

resource "google_apigee_instance" "instance" {
  org_id               = google_apigee_organization.org.id
  name                 = var.region
  location             = var.region
  consumer_accept_list = [var.project_id]

  timeouts {
    create = "90m"
  }
}

resource "google_apigee_environment" "env" {
  for_each     = var.environments
  org_id       = google_apigee_organization.org.id
  name         = each.key
  display_name = coalesce(each.value.display_name, each.key)
  description  = coalesce(each.value.description, local.is_payg ? "${each.value.type} environment" : "Environment")
  type         = local.is_payg ? each.value.type : null
}

resource "google_apigee_environment_addons_config" "analytics" {
  for_each          = local.analytics_envs
  env_id            = google_apigee_environment.env[each.key].id
  analytics_enabled = true
}

resource "google_apigee_instance_attachment" "env" {
  for_each    = var.environments
  instance_id = google_apigee_instance.instance.id
  environment = google_apigee_environment.env[each.key].name
}

resource "google_apigee_envgroup" "group" {
  for_each  = local.envgroups
  org_id    = google_apigee_organization.org.id
  name      = each.value
  hostnames = local.hostnames[each.value]
}

resource "google_apigee_envgroup_attachment" "env" {
  for_each    = local.env_group_of
  envgroup_id = google_apigee_envgroup.group[each.value].id
  environment = google_apigee_environment.env[each.key].name
}
