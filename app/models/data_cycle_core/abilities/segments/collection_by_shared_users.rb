# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class CollectionBySharedUsers < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::Collection
        end

        def conditions
          { my_selection: false, shared_users: { id: user.id } }
        end
      end
    end
  end
end
