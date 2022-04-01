# frozen_string_literal: true

require 'csv'

module DataCycleCore
  module Generic
    module Csv
      class Endpoint
        def initialize(**options)
          @csv_file = options.dig(:options, :filename)
        end

        def csv_categories(lang: :de)
          Enumerator.new do |yielder|
            load_data(@csv_file, lang).each do |category_data|
              yielder << {
                'id' => category_data.dig('key'),
                'name' => category_data.dig('name'),
                'parentId' => category_data.dig('parent').present? ? Digest::MD5.new.update(category_data.dig('parent')).hexdigest : nil
              }
            end
          end
        end

        protected

        def load_data(csv_file, _lang = :de)
          csv_text = File.read(Rails.root.join(DataCycleCore.external_sources_path, 'csv', csv_file))
          csv = CSV.parse(csv_text, { headers: true, col_sep: ';' })

          all_items = []
          parents = csv.values_at('parent')
          parents&.map(&:first)&.uniq&.compact&.each do |value|
            all_items << {
              'key' => Digest::MD5.new.update(value).hexdigest,
              'name' => value,
              'parent' => nil
            }
          end
          csv.each do |row|
            all_items << row.to_h
          end
          all_items
        end
      end
    end
  end
end
