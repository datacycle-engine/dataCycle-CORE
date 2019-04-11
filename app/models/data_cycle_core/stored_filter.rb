# frozen_string_literal: true

module DataCycleCore
  class StoredFilter < ApplicationRecord
    scope :by_user, ->(user) { where user: user }
    belongs_to :user

    def apply
      query_params = language.include?('all') ? [nil, DataCycleCore::Thing] : [language]
      query = DataCycleCore::Filter::Search.new(*query_params).exclude_templates_embedded

      parameters.presence&.each do |filter|
        if filter['m'] == 'e' && query.respond_to?("not_#{filter['t']}")
          query = query.send("not_#{filter['t']}", filter['v'])
        elsif filter['m'] != 'e' && query.respond_to?(filter['t'])
          query = query.send(filter['t'], filter['v'])
        end
      end
      query
    end
  end
end
