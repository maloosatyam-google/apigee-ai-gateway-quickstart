# -----------------------------------------------------------------------------
# Core Project & Apigee Configuration
# -----------------------------------------------------------------------------
variable "project_id" {
  description = "Google Cloud project ID. The Apigee organization is created with the same name."
  type        = string
}

variable "region" {
  description = "GCP region for the Apigee instance, Model Armor templates, and PSC networking (e.g., us-central1)."
  type        = string
  default     = "us-central1"
  validation {
    condition     = !can(regex("-[a-z]$", var.region))
    error_message = "region must be a GCP region (e.g., us-central1), not a zone (e.g., us-central1-a)."
  }
}

variable "billing_type" {
  description = "Apigee billing type: PAYG (Pay-as-you-go) or SUBSCRIPTION."
  type        = string
  default     = "PAYG"
  validation {
    condition     = contains(["PAYG", "SUBSCRIPTION"], var.billing_type)
    error_message = "billing_type must be PAYG or SUBSCRIPTION."
  }
}

variable "environments" {
  description = "Apigee environments to create. Defaults to a single PAYG INTERMEDIATE environment 'dev' with Analytics enabled."
  type = map(object({
    type         = optional(string, "INTERMEDIATE")
    analytics    = optional(bool, true)
    envgroup     = optional(string)
    display_name = optional(string)
    description  = optional(string)
  }))
  default = {
    dev = {}
  }
  validation {
    condition     = alltrue([for e in values(var.environments) : contains(["BASE", "INTERMEDIATE", "COMPREHENSIVE"], e.type)])
    error_message = "environment type must be BASE, INTERMEDIATE, or COMPREHENSIVE."
  }
}

# -----------------------------------------------------------------------------
# Northbound Routing (PSC + Load Balancer)
# -----------------------------------------------------------------------------
variable "routing" {
  description = "Northbound access: external (PSC + global external HTTPS LB), internal (PSC endpoint), or none."
  type        = string
  default     = "external"
  validation {
    condition     = contains(["external", "internal", "none"], var.routing)
    error_message = "routing must be external, internal, or none."
  }
}

variable "envgroup_hostnames" {
  description = "Optional custom hostnames per envgroup. When empty and routing='external', uses <group>.<lb-ip-dashed>.nip.io."
  type        = map(list(string))
  default     = {}
}

variable "lb_name_prefix" {
  description = "Prefix for load balancer and PSC networking resource names."
  type        = string
  default     = "apigee"
}

variable "psc_subnet_cidr" {
  description = "CIDR range for the dedicated PSC consumer subnetwork."
  type        = string
  default     = "10.0.0.0/28"
}

# -----------------------------------------------------------------------------
# Service Account, Model Armor, Product, Developer & App
# -----------------------------------------------------------------------------
variable "proxy_sa_id" {
  description = "Account ID for the dedicated Apigee proxy runtime Service Account."
  type        = string
  default     = "apigee-ai-gateway-sa"
}

variable "gemini_model" {
  description = "Vertex AI Gemini model ID allowed by the API Product and LLM Token Quota."
  type        = string
  default     = "gemini-3.6-flash"
}

variable "llm_token_quota_limit" {
  description = "Maximum tokens allowed per quota interval."
  type        = number
  default     = 1000
}

variable "llm_token_quota_interval" {
  description = "Quota interval count."
  type        = number
  default     = 1
}

variable "llm_token_quota_time_unit" {
  description = "Quota time unit (minute, hour, day, week, month)."
  type        = string
  default     = "minute"
}

variable "api_product_name" {
  description = "Name of the Apigee API Product with LLM Token Quota."
  type        = string
  default     = "ai-gateway-product"
}

variable "developer_email" {
  description = "Email address for the sample Apigee developer."
  type        = string
  default     = "ai-developer@example.com"
}

variable "developer_first_name" {
  description = "First name for the sample Apigee developer."
  type        = string
  default     = "AI"
}

variable "developer_last_name" {
  description = "Last name for the sample Apigee developer."
  type        = string
  default     = "Developer"
}

variable "developer_app_name" {
  description = "Name of the sample Apigee developer app."
  type        = string
  default     = "ai-gateway-quickstart-app"
}

variable "custom_report_name" {
  description = "Name of the Apigee custom report for LLM token consumption."
  type        = string
  default     = "llm-consumption-report"
}
