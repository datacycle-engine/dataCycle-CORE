# frozen_string_literal: true

module DataCycleCore
  module Feature
    class GeoKeyFigure < Base
      class << self
        def data_hash_module
          DataCycleCore::Feature::DataHash::GeoKeyFigure
        end

        def controller_module
          DataCycleCore::Feature::ControllerFunctions::GeoKeyFigure
        end

        def part_id_path(content)
          configuration(content).dig('part_id_path')
        end

        def local(content)
          configuration(content).dig('local')
        end
      end
    end
  end
end
