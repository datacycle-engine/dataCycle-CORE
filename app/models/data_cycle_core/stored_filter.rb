module DataCycleCore
  class StoredFilter < ApplicationRecord
    scope :by_user, ->(user) { where user: user }
    belongs_to :user

    def apply
      query = DataCycleCore::Filter::Search.new(language || 'de')
      parameters.each do |key, value|
        raise "function #{key} is not defined for class #{query.class}" unless query.respond_to?(key)
        if value.is_a?(Hash)
          value.each_value do |item|
            query = query.send(key, item)
          end
        else
          query = query.send(key, value)
        end
      end
      query
    end
  end
end
