module DataCycleCore
  module Json
    class Download < DataCycleCore::Generic::DownloadBase
      attr_reader :logging_strategy

      def download(**options, &block)
        if options.try(:[], :logging_strategy).blank?
          @logging = DataCycleCore::Generic::Logger::Console.new
        else
          @logging = options[:logging_strategy]
        end
        download_images(**options)
      end

      def download_images(**options)
        download_data(ImageObject, ->(data) { data['url'] }, ->(data) { data['headline'] }, options)
      end

      protected

      def endpoint
        @endpoint ||= Endpoint.new(Hash[credentials.map { |k, v| [k.to_sym, v] }])
      end
    end
  end
end
