# frozen_string_literal: true

require 'csv'

module DataCycleCore
  module Report
    class Base
      attr_reader :data, :locale, :params

      def initialize(params: nil, locale: 'de')
        @locale = locale
        @params = params
        @data = apply(params)
      end

      def apply(_params)
        raise NotImplementedError
      end

      def available_params
        raise NotImplementedError
      end

      def to_csv
        generate_csv
      end

      def to_tsv
        separator = "\t"
        mime_type = 'text/tab-separated-values'
        file_extension = 'tsv'
        generate_csv(file_extension:, separator:, mime_type:)
      end

      def to_json(*_args)
        mime_type = 'application/json'
        return { (@params.dig(:key) || 'data') => @data }.to_json, { filename: "#{@params.dig(:key) || 'report'}.json", disposition: 'attachment', type: mime_type }
      end

      def generate_csv(file_extension: 'csv', separator: ';', mime_type: 'text/csv')
        options = { col_sep: separator }
        csv_string = CSV.generate(options) do |csv|
          csv << translated_headings
          @data.to_a.each do |value|
            csv << value.values
          end
        end
        return csv_string, { filename: "#{@params.dig(:key) || 'report'}.#{file_extension}", disposition: 'attachment', type: mime_type }
      end

      def to_xlsx
        p = Axlsx::Package.new
        wb = p.workbook
        s = wb.styles
        header = s.add_style bg_color: 'DD', sz: 16, b: true, alignment: { horizontal: :center }
        title = I18n.t "feature.report_generator.#{@params.dig(:key)}", default: @params.dig(:key), locale: @locale

        wb.add_worksheet(name: title.parameterize(separator: ' ', preserve_case: true).truncate(31)) do |sheet|
          sheet.add_row translated_headings, style: header
          @data.to_a.each do |value|
            sheet.add_row value.values
          end
        end
        mime_type = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        return p.to_stream.read, { filename: "#{@params.dig(:key) || 'report'}.xlsx", disposition: 'attachment', type: mime_type }
      end

      private

      def translated_headings
        @data.fields.map { |key| I18n.t "feature.report_generator.headings.#{key}", default: key, locale: @locale }
      end
    end
  end
end
