# frozen_string_literal: true

module DataCycleCore
  class AssetContent < ApplicationRecord
    belongs_to :thing
    belongs_to :asset, dependent: :destroy # destroy asset when asset_content is destroyed

    scope :with_content, ->(content_id) { where(thing_id: content_id) }
    scope :with_assets, ->(ids, type) { where(asset_id: ids, asset_type: type) }
    scope :with_relation, ->(relation_name) { where(relation: relation_name) }
  end
end
