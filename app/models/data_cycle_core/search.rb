# frozen_string_literal: true

module DataCycleCore
  class Search < ApplicationRecord
    belongs_to :content_data, polymorphic: true
  end
end
