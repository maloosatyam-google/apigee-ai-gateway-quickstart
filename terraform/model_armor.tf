# Model Armor template for incoming user prompts (RAI + Prompt Injection/Jailbreak + Malicious URIs)
resource "google_model_armor_template" "sanitize_user_prompt" {
  location    = var.region
  template_id = "apigee-sanitize-user-prompt"

  filter_config {
    rai_settings {
      rai_filters {
        filter_type      = "HATE_SPEECH"
        confidence_level = "HIGH"
      }
      rai_filters {
        filter_type      = "DANGEROUS"
        confidence_level = "HIGH"
      }
      rai_filters {
        filter_type      = "SEXUALLY_EXPLICIT"
        confidence_level = "HIGH"
      }
      rai_filters {
        filter_type      = "HARASSMENT"
        confidence_level = "HIGH"
      }
    }

    pi_and_jailbreak_filter_settings {
      filter_enforcement = "ENABLED"
      confidence_level   = "HIGH"
    }

    malicious_uri_filter_settings {
      filter_enforcement = "ENABLED"
    }
  }

  depends_on = [google_project_service.apis]
}

# Model Armor template for LLM responses (RAI + Sensitive Data Protection)
resource "google_model_armor_template" "sanitize_model_response" {
  location    = var.region
  template_id = "apigee-sanitize-model-response"

  filter_config {
    rai_settings {
      rai_filters {
        filter_type      = "HATE_SPEECH"
        confidence_level = "HIGH"
      }
      rai_filters {
        filter_type      = "DANGEROUS"
        confidence_level = "HIGH"
      }
      rai_filters {
        filter_type      = "SEXUALLY_EXPLICIT"
        confidence_level = "HIGH"
      }
      rai_filters {
        filter_type      = "HARASSMENT"
        confidence_level = "HIGH"
      }
    }

    sdp_settings {
      basic_config {
        filter_enforcement = "ENABLED"
      }
    }
  }

  depends_on = [google_project_service.apis]
}
