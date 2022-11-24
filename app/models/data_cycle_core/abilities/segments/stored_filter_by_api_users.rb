# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class StoredFilterByApiUsers < Base
        attr_reader :subject

        def initialize(**_additional_conditions)
          @subject = DataCycleCore::StoredFilter
        end

        def scope
          ['stored_filters.api = ? AND (stored_filters.system = ? OR ? = ANY(stored_filters.api_users))', true, true, user.id]
        end

        def include?(sf, *_args)
          sf.api && (sf.system || sf.api_users&.include?(user.id))
        end

        def to_proc
          ->(*args) { include?(*args) }
        end
      end
    end
  end
end
