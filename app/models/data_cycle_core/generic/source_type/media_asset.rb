class DataCycleCore::Generic::SourceType::MediaAsset
  include Mongoid::Document

  store_in collection: 'media_assets'

  field :external_id,  type: String
  field :dump,         type: Hash
  field :seen_at,      type: DateTime
  include Mongoid::Timestamps

  before_save -> (document) { document.seen_at = DateTime.now }
end
