# frozen_string_literal: true

module DataCycleCore
  module Generic
    class CollectionBase
      include Mongoid::Document

      attr_accessor :data_has_changed

      store_in collection: 'name'

      field :external_id,  type: String
      field :dump,         type: Hash
      field :seen_at,      type: DateTime
      include Mongoid::Timestamps

      before_save ->(document) { document.seen_at = Time.zone.now }

      def set_updated_at
        super if data_has_changed
      end
    end
  end
end
