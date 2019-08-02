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

        def download_zip
          @object = DataCycleCore::Thing.find(params[:id])
          authorize! :download_zip, @object
          serialize_format = params.dig(:serialize_format)&.select { |_, v| v.to_i.positive? }&.keys
          languages = params[:language]
          raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless DataCycleCore::Feature::Download.valid_collection_format?('content', serialize_format)

          download_items = ([@object] + @object.content_b_linked).to_a.select do |thing|
            can? :download, thing
          end

          download_collection(@object, download_items, serialize_format, languages)
        end
      end
    end
  end
end
