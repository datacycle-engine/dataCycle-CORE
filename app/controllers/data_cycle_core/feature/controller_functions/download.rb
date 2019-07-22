# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module Download
        include DataCycleCore::DownloadHandler

        def download
          @object = DataCycleCore::Thing.find_by(id: params[:id])
          authorize! :download, @object
          download_single(@object)
        end
      end
    end
  end
end
