# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module Embedded
        class << self
          def gip_start_end_waypoints(**_additional_args)
            [{ name: 'Start' }, { name: 'Ende' }]
          end
        end
      end
    end
  end
end
