# frozen_string_literal: true

module DataCycleCore
  class Search < ApplicationRecord
    attr_readonly :dict
    belongs_to :content_data, class_name: 'DataCycleCore::Thing'
    belongs_to :pg_dict_mapping, foreign_key: :locale, inverse_of: :searches
  end
end
