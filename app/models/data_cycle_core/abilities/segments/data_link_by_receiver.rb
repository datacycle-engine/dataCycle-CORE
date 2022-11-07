# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class DataLinkByReceiver < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::DataLink
        end

        def conditions
          { receiver_id: user&.id }
        end
      end
    end
  end
end
