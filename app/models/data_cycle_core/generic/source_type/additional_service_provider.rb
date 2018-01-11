class DataCycleCore::Generic::SourceType::AdditionalServiceProvider
  include Mongoid::Document

  store_in collection: 'additional_service_providers'

  field :external_id,  type: String
  field :dump,         type: Hash
  field :seen_at,      type: DateTime
  include Mongoid::Timestamps

  before_save ->(document) { document.seen_at = DateTime.now }
end
