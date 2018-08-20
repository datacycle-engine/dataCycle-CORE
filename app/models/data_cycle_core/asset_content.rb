# frozen_string_literal: true

module DataCycleCore
  class AssetContent < ApplicationRecord
    belongs_to :content_data, polymorphic: true
    belongs_to :asset

    def for_content(content_id, content_type)
      where(content_data_id: content_id, content_data_type: content_type)
    end

    def for_assets(ids, type)
      where(asset_id: ids, asset_type: type)
    end

    def for_rleation(relation_name)
      where(relation_name: relation_name)
    end
  end
end
