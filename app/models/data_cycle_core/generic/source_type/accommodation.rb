class DataCycleCore::Generic::SourceType::Accommodation
  include Mongoid::Document

  store_in collection: 'accommodations'

  field :external_id,  type: String
  field :dump,         type: Hash
  field :seen_at,      type: DateTime
  include Mongoid::Timestamps

  before_save -> (document) { document.seen_at = DateTime.now }
end
