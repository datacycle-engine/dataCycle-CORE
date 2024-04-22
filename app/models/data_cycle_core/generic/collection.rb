# frozen_string_literal: true

module DataCycleCore
  module Generic
    class Collection
      include Mongoid::Document

      attr_accessor :data_has_changed, :keep_seen_at

      store_in collection: 'name'

      field :external_id,      type: String
      field :dump,             type: Hash
      field :external_system,  type: Hash
      field :seen_at,          type: DateTime
      include Mongoid::Timestamps

      before_save ->(document) { document.seen_at = Time.zone.now unless keep_seen_at }

      def set_updated_at
        super if data_has_changed
      end
    end
  end
end
