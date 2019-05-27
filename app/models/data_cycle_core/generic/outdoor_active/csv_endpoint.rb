# frozen_string_literal: true

require 'csv'

module DataCycleCore
  module Generic
    module OutdoorActive
      class CsvEndpoint < DataCycleCore::Generic::Csv::Endpoint
        def initialize(**options)
          @csv_file = options.dig(:options, :filename)
        end

        def external_categories(lang: :de)
          csv_categories(lang: lang)
        end

        def external_source_keys(lang: :de)
          csv_categories(lang: lang)
        end

        def external_statuses(lang: :de)
          csv_categories(lang: lang)
        end
      end
    end
  end
end
