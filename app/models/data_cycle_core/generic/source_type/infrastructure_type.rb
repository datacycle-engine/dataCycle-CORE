class DataCycleCore::Generic::SourceType::InfrastructureType
  include Mongoid::Document

  store_in collection: 'infrastructure_types'

  field :external_id,  type: String
  field :dump,         type: Hash
  field :seen_at,      type: DateTime
  include Mongoid::Timestamps

  before_save ->(document) { document.seen_at = DateTime.now }
end
