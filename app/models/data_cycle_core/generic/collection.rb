# frozen_string_literal: true

module DataCycleCore
  module Generic
    class Collection
      include Mongoid::Document

      store_in collection: 'name'

      field :external_id,  type: String
      field :dump,         type: Hash
      field :seen_at,      type: DateTime
      include Mongoid::Timestamps

      before_save ->(document) { document.seen_at = Time.zone.now }
    end
  end
end
