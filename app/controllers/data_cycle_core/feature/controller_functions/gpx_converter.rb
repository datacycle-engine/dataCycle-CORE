# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module GpxConverter
        def gpx
          @object = DataCycleCore::Thing.find_by(id: params[:id])
          authorize! :show, @object
          send_data @object.create_gpx, filename: "#{@object.title.blank? ? 'unnamed_place' : @object.title.parameterize(separator: '_')}.gpx", type: 'gpx/xml'
        end
      end
    end
  end
end
