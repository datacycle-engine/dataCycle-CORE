# frozen_string_literal: true

Rails.application.reloader.to_prepare do
  ActiveRecord::Type.register(:stored_filter_parameters_type, DataCycleCore::StoredFilterParametersType)
end
