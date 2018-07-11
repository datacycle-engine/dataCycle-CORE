# frozen_string_literal: true

module DataCycleCore
  class StoredFilter < ApplicationRecord
    scope :by_user, ->(user) { where user: user }
    belongs_to :user

    def apply
      query = DataCycleCore::Filter::Search.new(language || DataCycleCore.ui_language)

      parameters.presence&.each do |filter|
        query = query.send(filter['t'], filter['v']) if query.respond_to?(filter['t'])
      end
      query
    end
  end
end
