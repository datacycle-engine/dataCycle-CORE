# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class StoredFilterByApiUsers < Base
        attr_reader :subject, :scope

        def initialize(**_additional_conditions)
          @subject = DataCycleCore::StoredFilter
          @scope = ['api = ? AND ? = ANY(api_users)', true, user&.id]
        end

        def include?(sf, *_args)
          sf.api && sf.api_users&.include?(user.id)
        end

        def to_proc
          ->(*args) { include?(*args) }
        end
      end
    end
  end
end
