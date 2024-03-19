# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class AssetByUserAndNoContent < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::Asset
        end

        def conditions
          { creator_id: user&.id, asset_content: { id: nil } }
        end

        private

        def to_restrictions(subject:, **)
          to_restriction(data: subject.model_name.human(locale:))
        end
      end
    end
  end
end
