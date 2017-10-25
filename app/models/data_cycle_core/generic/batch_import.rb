module DataCycleCore
  module Generic
    class BatchImport < DataCycleCore::Generic::Base

      def import(**options, &block)
        options[:import].each do |_, single_config|
          DataCycleCore::Generic::Import.new(external_source.id).import(options.merge({import: single_config.symbolize_keys}))
        end
      end

    end
  end
end
