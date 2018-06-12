# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadFunctions
        def self.download_data(download_object:, data_id:, data_name:, options:)
          options[:locales] ||= I18n.available_locales

          if options[:locales].size != 1
            options[:locales].each do |language|
              download_data(download_object: download_object, data_id: data_id, data_name: data_name, options: options.except(:locales).merge({ locales: [language] }))
            end
          else

            locale = options[:locales].first
            Mongoid.override_database("#{download_object.source_type.database_name}_#{download_object.external_source.id}")
            download_object.logging.preparing_phase("#{download_object.source_type.collection_name}_#{locale}")
            item_count = 0

            begin
              download_object.source_object.with(download_object.source_type) do |mongo_item|
                items = download_object.endpoint.send(options.dig(:download, :endpoint_method) || download_object.source_type.collection_name.to_s, lang: locale)

                max_string = ''
                max_string += (options[:max_count]).to_s if options[:max_count]
                download_object.logging.phase_started("#{download_object.source_type.collection_name}_#{locale}", max_string)

                durations = []

                items.each do |item_data|
                  break if options[:max_count] && item_count >= options[:max_count]
                  durations << Benchmark.realtime do
                    item_count += 1
                    next if item_data.nil?

                    begin
                      item_id = data_id.call(item_data)
                      item_name = data_name.call(item_data)

                      item = mongo_item.find_or_initialize_by('external_id': item_id)

                      item.dump ||= {}
                      item.dump[locale] = item_data
                      item.save!
                      download_object.logging.item_processed(item_name, item_id, item_count, max_string)
                    rescue StandardError => e
                      download_object.logging.error(item_name, item_id, item_data, e)
                    end

                    next unless (item_count % 100).zero?

                    GC.start
                    download_object.logging.info("Downloaded #{item_count} items in #{durations.sum} seconds", nil)
                  end
                end
              end
            rescue StandardError => e
              download_object.logging.error(nil, nil, nil, e)
            ensure
              Mongoid.override_database(nil)

              download_object.logging.phase_finished("#{download_object.source_type.collection_name}_#{locale}", item_count)
            end
          end
        end
      end
    end
  end
end
