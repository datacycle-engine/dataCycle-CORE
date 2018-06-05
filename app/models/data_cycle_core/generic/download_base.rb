# frozen_string_literal: true

module DataCycleCore
  module Generic
    class DownloadBase < Base
      protected

      def download_data(type, extract_id, extract_name, **options)
        options[:locales] ||= I18n.available_locales

        if options[:locales].size != 1
          options[:locales].each do |language|
            download_data(type, extract_id, extract_name, options.except(:locales).merge({ locales: [language] }))
          end
        else

          locale = options[:locales].first
          Mongoid.override_database("#{type.database_name}_#{external_source.id}")
          @logging.preparing_phase("#{type.collection_name}_#{locale}")
          item_count = 0

          begin
            @source_object.with(@source_type) do |mongo_item|
              items = endpoint.send(options.dig(:download, :endpoint_method) || type.collection_name.to_s, lang: locale)

              max_string = ''
              max_string += (options[:max_count]).to_s if options[:max_count]
              @logging.phase_started("#{type.collection_name}_#{locale}", max_string)

              durations = []

              items.each do |item_data|
                break if options[:max_count] && item_count >= options[:max_count]
                durations << Benchmark.realtime do
                  item_count += 1
                  next if item_data.nil?

                  begin
                    item_id = extract_id.call(item_data)
                    item_name = extract_name.call(item_data)

                    item = mongo_item.find_or_initialize_by('external_id': item_id)

                    item.dump ||= {}
                    item.dump[locale] = item_data
                    item.save!
                    @logging.item_processed(item_name, item_id, item_count, max_string)
                  rescue StandardError => e
                    @logging.error(item_name, item_id, item_data, e)
                  end

                  next unless (item_count % 100).zero?

                  GC.start
                  @logging.info("Downloaded #{item_count} items in #{durations.sum} seconds", nil)
                end
              end
            end
          rescue StandardError => e
            @logging.error(nil, nil, nil, e)
          ensure
            Mongoid.override_database(nil)

            @logging.phase_finished("#{type.collection_name}_#{locale}", item_count)
          end
        end
      end
    end
  end
end
