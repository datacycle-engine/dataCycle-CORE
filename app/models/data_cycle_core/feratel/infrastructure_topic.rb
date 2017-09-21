class DataCycleCore::Feratel::InfrastructureTopic
  include Mongoid::Document

  store_in collection: 'infrastructure_topics'

  field :external_id,  type: String
  field :dump,         type: Hash
  field :seen_at,      type: DateTime
  include Mongoid::Timestamps

  before_save -> (document) { document.seen_at = DateTime.now }
end
