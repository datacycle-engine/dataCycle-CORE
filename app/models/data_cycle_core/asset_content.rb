# frozen_string_literal: true

module DataCycleCore
  class AssetContent < ApplicationRecord
    belongs_to :content_data, class_name: 'DataCycleCore::Thing'
    belongs_to :asset

    class << self
      def with_content(content_id)
        where(content_data_id: content_id)
      end

      def with_assets(ids, type)
        where(asset_id: ids, asset_type: type)
      end

      def with_relation(relation_name)
        where(relation: relation_name)
      end
    end
  end
end
