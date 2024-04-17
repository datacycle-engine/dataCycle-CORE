# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class CollectionByCreatorAndApi < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::Collection
        end

        def conditions
          { my_selection: false, user_id: user&.id, api: true }
        end
      end
    end
  end
end
