# frozen_string_literal: true

require 'csv'

module DataCycleCore
  module Report
    class Base
      attr_reader :data
      attr_reader :locale

      def initialize(params: nil, locale: 'de')
        @locale = locale
        @data = apply(params)
      end

      def apply(_params)
      end

      def available_params
      end

      def to_csv
        generate_csv
      end

      def to_tsv
        separator = "\t"
        mime_type = 'text/tab-separated-values'
        file_extension = 'tsv'
        generate_csv(file_extension: file_extension, separator: separator, mime_type: mime_type)
      end

      def to_json(*_args)
        mime_type = 'application/json'
        return @data.as_json, { filename: 'test.json', disposition: 'attachment', type: mime_type }
      end

      def generate_csv(file_extension: 'csv', separator: ';', mime_type: 'text/csv')
        return if @data.empty?
        options = { col_sep: separator }
        csv_string = CSV.generate(options) do |csv|
          csv << translated_headings
          @data.each do |value|
            csv << value.values
          end
        end
        return csv_string, { filename: "test.#{file_extension}", disposition: 'attachment', type: mime_type }
      end

      def translated_headings
        @data.first.keys.map { |key| I18n.t "feature.report_generator.headings.#{key}", default: key }
      end
    end
  end
end
