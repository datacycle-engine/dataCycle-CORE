# frozen_string_literal: true

module DataCycleCore
  class AssetContent < ApplicationRecord
    belongs_to :content_data, polymorphic: true
    belongs_to :asset
  end
end
