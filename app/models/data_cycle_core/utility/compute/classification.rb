# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Classification
        class << self
          def keywords(**args)
            tags = args.dig(:computed_parameters).presence&.try(:flatten)
            return if tags.blank?
            DataCycleCore::Classification.find(tags)&.map(&:name)&.join(',')
          end
        end
      end
    end
  end
end
