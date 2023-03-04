# frozen_string_literal: true

module DataCycleCore
  class CollectionConfiguration < ApplicationRecord
    belongs_to :watch_list
    belongs_to :stored_filter

    before_save :update_slug, if: :slug_changed?
    after_save :reload, if: :saved_change_to_slug?

    private

    def update_slug
      self.slug = (slug.presence || watch_list&.name.presence || stored_filter&.name.presence)&.to_slug
    end
  end
end
