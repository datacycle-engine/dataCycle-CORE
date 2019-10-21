# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module Download
        include DataCycleCore::DownloadHandler

        def download
          @object = DataCycleCore::Thing.find_by(id: permitted_download_params[:id])
          serialize_format = permitted_download_params[:serialize_format]
          languages = permitted_download_params[:language]
          version = permitted_download_params[:version]
          transformation = permitted_download_params.dig(:transformation, version)&.reject { |_k, v| v == 'none' }
          authorize! :download, @object
          download_content(@object, serialize_format, languages, version, transformation)
        end

        def download_zip
          @object = DataCycleCore::Thing.find(permitted_download_params[:id])
          authorize! :download_zip, @object
          serialize_format = permitted_download_params.dig(:serialize_format)&.select { |_, v| v.to_i.positive? }&.keys
          languages = permitted_download_params[:language]
          raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless DataCycleCore::Feature::Download.valid_collection_format?('content', serialize_format)

          download_items = ([@object] + @object.content_b_linked).to_a.select do |thing|
            can? :download, thing
          end

          download_collection(@object, download_items, serialize_format, languages)
        end

        def download_indesign
          @object = DataCycleCore::Thing.find(permitted_download_params[:id])
          authorize! :download_indesign, @object
          serialize_format = [permitted_download_params.dig(:serialize_format)]
          languages = permitted_download_params[:language]
          raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless DataCycleCore::Feature::Download.valid_collection_format?('content', serialize_format)

          download_items = ([@object] + @object.linked_contents.where(template_name: 'Bild')).to_a.select do |thing|
            can? :download, thing
          end

          download_indesign_collection(@object, download_items, serialize_format, languages)
        end

        private

        def permitted_download_params
          params.permit(:id, :language, :serialize_format, :version, transformation: [params[:version]&.to_sym => [:format]], serialize_format: {})
        end
      end
    end
  end
end
