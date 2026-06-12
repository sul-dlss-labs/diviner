# frozen_string_literal: true

RubyLLM.configure do |config|
  # OpenAI-compatible gateway configuration (hard-coded for now).
  config.openai_api_base = Settings.openai_api.base
  config.openai_api_key = Settings.openai_api.key

  config.default_model = Settings.default_model

  config.gemini_api_key = Settings.gemini_api.key

  config.vertexai_service_account_key = Base64.decode64(Settings.vertexai_api.key)
  config.vertexai_project_id = Settings.vertexai_api.project_id
  config.vertexai_location = Settings.vertexai_api.location

  # Total wait time before giving up on a request should be 60 seconds.
  config.request_timeout = 60
  config.max_retries = 0
  config.logger = Rails.logger
  # Use the new association-based acts_as API (recommended)
  config.use_new_acts_as = true
end
