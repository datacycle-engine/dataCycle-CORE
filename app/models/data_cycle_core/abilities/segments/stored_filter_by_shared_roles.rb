# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class StoredFilterBySharedRoles < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::StoredFilter
        end

        def conditions
          { shared_roles: { id: user.role_id } }
        end
      end
    end
  end
end
