# frozen_string_literal: true

Rails.application.reloader.to_prepare do
  ActiveRecord::Type.register(:'stored_filter/parameters', DataCycleCore::Type::StoredFilter::Parameters)

  # Thing Properties
  ActiveRecord::Type.register(:'thing/string', DataCycleCore::Type::Thing::String)
end
