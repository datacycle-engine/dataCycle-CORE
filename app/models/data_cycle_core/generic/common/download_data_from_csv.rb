# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadDataFromCsv
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_content(
            download_object: utility_object,
            iterator: method(:load_data_from_csv).to_proc,
            data_id: method(:data_id).to_proc.curry[options.dig(:download, :external_id_hash_method)],
            options:,
            iterate_credentials: false
          )
        end

        def self.load_data_from_csv(options:, **_keyword_args)
          file_path = options.dig(:download, :file)
          raise ArgumentError, 'missing file path!' if file_path.nil?

          # options
          separator = options.dig(:download, :separator) || ','
          headers = options.dig(:download, :headers) || true

          data_id_path = options.dig(:download, :data_id_path)

          raise ArgumentError, 'missing data_id_path path!' if data_id_path.nil?

          path = Rails.root.join(file_path)
          modified_at = File.mtime(path).iso8601
          data = []

          CSV.foreach(file_path, headers: headers, skip_blanks: true, col_sep: separator) do |row|
            data << row.to_h.merge({
              'id' => row[data_id_path],
              'modifiedAt' => modified_at
            })
          end

          data
        end

        def self.data_id(external_id_hash_method, data)
          case external_id_hash_method
          when 'MD5'
            Digest::MD5.hexdigest(data['id'])
          else
            data['id']&.to_s
          end
        end
      end
    end
  end
end
