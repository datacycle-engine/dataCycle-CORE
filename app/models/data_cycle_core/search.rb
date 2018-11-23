# frozen_string_literal: true

module DataCycleCore
  class Search < ApplicationRecord
    belongs_to :content_data, class_name: 'DataCycleCore::Thing'
  end
end
