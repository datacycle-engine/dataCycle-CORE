module DataCycleCore
  module Jsonld
    class Download < DataCycleCore::Import::DownloadBase
      def download(**options, &block)
        callbacks = DataCycleCore::Callbacks.new(block)

        download_images(callbacks, **options)
      end

      def download_images(callbacks = DataCycleCore::Callbacks.new, **options)
        download_data(ImageObject, ->(data) { data['url'] }, ->(data) { data['headline'] }, callbacks, options)
      end

      protected

      def endpoint
        @endpoint ||= Endpoint.new(Hash[credentials.map { |k, v| [k.to_sym, v] }])
      end
    end
  end
end
