module DataCycleCore::Import
  class DownloadBase < Base

    protected

    def download_data(type, extract_id, extract_name, callbacks = DataCycleCore::Callbacks.new, **options)
      options[:locales] ||= I18n.available_locales

      if options[:locales].size != 1
        options[:locales].each do |l|
          download_data(type, extract_id, extract_name, callbacks, options.except(:locales).merge({locales: [l]}))
        end
      else
        locale = options[:locales].first

        Mongoid.override_database("#{type.database_name}_#{external_source.id}")

        callbacks.execute_callback(:preparing_phase, "#{type.to_s.demodulize.underscore.pluralize}_#{locale}")

        item_count = 0

        begin
          items = endpoint.send("#{type.to_s.demodulize.underscore.pluralize}", lang: locale)

          callbacks.execute_callback(:phase_started, "#{type.to_s.demodulize.underscore.pluralize}_#{locale}")

          items.each do |item_data|
            item_count += 1

            begin
              item_id = extract_id.(item_data)
              item_name = extract_name.(item_data)

              item = type.find_or_initialize_by('external_id': item_id)

              item.dump ||= {}
              item.dump[locale] = item_data
              item.save!

              callbacks.execute_callback(:item_processed, item_name, item_id, item_count, nil)
            rescue => e
              callbacks.execute_callback(:error, item_name, item_id, item_data, e)
            end

            return if options[:max_count] && item_count >= options[:max_count]
          end
        rescue DataCycleCore::Import::RecoverableError => e
          callbacks.execute_callback(:error, nil, nil, nil, e)
        ensure
          Mongoid.override_database(nil)

          callbacks.execute_callback(:phase_finished, "#{type.to_s.demodulize.underscore.pluralize}_#{locale}", item_count)
        end
      end
    end
  end
end
