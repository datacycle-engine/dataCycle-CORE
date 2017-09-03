module DataCycleCore::Feratel
  class Download < DataCycleCore::Import::Base
    def download(options = {}, &block)
      callbacks = DataCycleCore::Callbacks.new(block)

      download_events(options, callbacks)
    end

    def download_events(options = {}, callbacks = DataCycleCore::Callbacks.new)
      Mongoid.override_database("#{Event.database_name}_#{external_source.id}")

      data = endpoint.load_events

      options[:max_count] ||= data.xpath('//Event').count

      callbacks.execute_callback(:phase_started, :events, options[:max_count])

      item_count = 0

      begin
        data.xpath('//Event').each do |xml_data|
          raw_event_data = xml_data.to_hash

          begin
            item_count += 1

            event_id = raw_event_data['Id']
            event_name = Array(raw_event_data['Details']['Names']['Translation']).find { |t| t['Language'] == I18n.locale.to_s }.try(:[], 'text')

            event = Event.find_or_initialize_by('external_id': event_id)
            event.dump = raw_event_data
            event.save!

            callbacks.execute_callback(:item_processed, event_name, event_id, item_count, options[:max_count])
          rescue => e
            callbacks.execute_callback(:error, event_name, event_id, raw_event_data, e)
          end
        end
      ensure
        Mongoid.override_database(nil)

        callbacks.execute_callback(:phase_finished, :events, item_count)
      end
    end

    protected

    def endpoint
      @endpoint ||= Endpoint.new(Hash[credentials.map { |k, v| [k.to_sym, v] }])
    end
  end
end
