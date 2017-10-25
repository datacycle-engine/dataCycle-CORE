module DataCycleCore
  module Generic
    class BatchDownload < DataCycleCore::Generic::Base

      def download(**options, &block)
        options[:download].each do |_, single_config|
          DataCycleCore::Generic::Download.new(external_source.id).download(options.merge({download: single_config.symbolize_keys}))
        end
      end

    end
  end
end
