# frozen_string_literal: true

module DataCycleCore
  module Feature
    class GipKeyFigure < Base
      class << self
        def data_hash_module
          DataCycleCore::Feature::DataHash::GipKeyFigure
        end

        def controller_module
          DataCycleCore::Feature::ControllerFunctions::GipKeyFigure
        end

        def part_id_path(content)
          configuration(content).dig('part_id_path')
        end
      end
    end
  end
end
