# frozen_string_literal: true

# switch active triggers according to configuration
Rails.application.configure do
  config.after_initialize do
    DataCycleCore::FilterService.update_pg_dict_mappings
  end
end
