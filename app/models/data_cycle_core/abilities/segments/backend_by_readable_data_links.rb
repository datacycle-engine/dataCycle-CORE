# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class BackendByReadableDataLinks < StoredFilterByDataLink
        private

        def valid_data_links?
          user.valid_received_readable_data_links.any?
        end
      end
    end
  end
end
