# frozen_string_literal: true

DataCycleCore::Translation::Translation.configure do |config|
  config.default_backend = :jsonb
  config.accessor_method = :translates
  config.query_method    = :i18n
  config.plugins(:query)
end
