# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module Download
        include DataCycleCore::DownloadHandler

        def download
          @object = DataCycleCore::Thing.find_by(id: params[:id])
          serialize_format = params[:serialize_format]
          languages = params[:language]

          authorize! :download, @object
          download_content(@object, serialize_format, languages)
        end
      end
    end
  end
end
