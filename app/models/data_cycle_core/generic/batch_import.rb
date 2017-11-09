module DataCycleCore
  module Generic
    class BatchImport < DataCycleCore::Generic::Base

      def import(**options, &block)
        options[:import].sort { |d1, d2|
          d1.second['sorting'] <=> d2.second['sorting']
        }.each do |_, single_config|
          DataCycleCore::Generic::Import.new(external_source.id).import(options.merge({import: single_config.symbolize_keys}))
        end
      end

    end
  end
end
