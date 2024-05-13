# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class CollectionBySharedRoles < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::Collection
        end

        def conditions
          { my_selection: false, shared_roles: { id: user.role_id } }
        end
      end
    end
  end
end
