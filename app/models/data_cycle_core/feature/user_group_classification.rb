# frozen_string_literal: true

module DataCycleCore
  module Feature
    class UserGroupClassification < Base
      class << self
        def attribute_keys(content = nil)
          Array.wrap(configuration(content).dig('attribute_keys')&.keys)
        end

        def attribute_relations(content = nil)
          configuration(content).dig('attribute_keys') || {}
        end
      end
    end
  end
end
