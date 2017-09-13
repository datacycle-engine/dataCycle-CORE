module DataCycleCore::Feratel
  class Download < DataCycleCore::Import::Base
    def download(options = {}, &block)
      callbacks = DataCycleCore::Callbacks.new(block)

      download_locations(options, callbacks)
      download_holiday_themes(options, callbacks)
      download_infrastructure_topics(options, callbacks)
      download_custom_attributes(options, callbacks)
      download_facility_groups(options, callbacks)
      download_facilities(options, callbacks)
      download_rating_questions(options, callbacks)
      download_infrastructure(options, callbacks)
      download_additional_service_providers(options, callbacks)
      download_events(options, callbacks)
    end

    def download_locations(options = {}, callbacks = DataCycleCore::Callbacks.new)
      download_data(Location, '//Location', options.clone, callbacks) do |data|
        [data['Id'], data['Name']]
      end
    end

    def download_holiday_themes(options = {}, callbacks = DataCycleCore::Callbacks.new)
      download_data(HolidayTheme, '//HolidayTheme', options.clone, callbacks) do |data|
        [
          data['Id'],
          Array(data['Name']['Translation']).find { |t| t['Language'] == I18n.locale.to_s }.try(:[], 'text')
        ]
      end
    end

    def download_infrastructure_topics(options = {}, callbacks = DataCycleCore::Callbacks.new)
      download_data(InfrastructureTopic, '//InfrastructureTopic', options.clone, callbacks) do |data|
        [
          data['Id'],
          Array(data['Name']['Translation']).find { |t| t['Language'] == I18n.locale.to_s }.try(:[], 'text')
        ]
      end
    end

    def download_custom_attributes(options = {}, callbacks = DataCycleCore::Callbacks.new)
      download_data(CustomAttribute, '//CustomAttribute', options.clone, callbacks) do |data|
        [data['Id'], data['Name']]
      end
    end

    def download_facility_groups(options = {}, callbacks = DataCycleCore::Callbacks.new)
      download_data(FacilityGroup, '//FacilityGroup', options.clone, callbacks) do |data|
        [
          data['Id'],
          Array(data['Name']['Translation']).find { |t| t['Language'] == I18n.locale.to_s }.try(:[], 'text')
        ]
      end
    end

    def download_facilities(options = {}, callbacks = DataCycleCore::Callbacks.new)
      download_data(Facility, '//Facility', options.clone, callbacks) do |data|
        [
          data['Id'],
          Array(data['Name']['Translation']).find { |t| t['Language'] == I18n.locale.to_s }.try(:[], 'text')
        ]
      end
    end

    def download_rating_questions(options = {}, callbacks = DataCycleCore::Callbacks.new)
      download_data(RatingQuestion, '//RatingQuestion', options.clone, callbacks) do |data|
        [
          data['Id'],
          Array(data['Name']['Translation']).find { |t| t['Language'] == I18n.locale.to_s }.try(:[], 'text')
        ]
      end
    end

    def download_infrastructure(options = {}, callbacks = DataCycleCore::Callbacks.new)
      download_data(InfrastructureItem, '//InfrastructureItem', options.clone, callbacks) do |data|
        [
          data['Id'],
          Array(data['Details']['Names']['Translation']).find { |t| t['Language'] == I18n.locale.to_s }.try(:[], 'text')
        ]
      end
    end

    def download_additional_service_providers(options = {}, callbacks = DataCycleCore::Callbacks.new)
      download_data(AdditionalServiceProvider, '//ServiceProvider', options.clone, callbacks) do |data|
        [
          data['Id'],
          Array(data['Details']['Names']['Translation']).find { |t| t['Language'] == I18n.locale.to_s }.try(:[], 'text')
        ]
      end
    end


    def download_events(options = {}, callbacks = DataCycleCore::Callbacks.new)
      download_data(Event, '//Event', options.clone, callbacks) do |data|
        [
          data['Id'],
          Array(data['Details']['Names']['Translation']).find { |t| t['Language'] == I18n.locale.to_s }.try(:[], 'text')
        ]
      end
    end

    def download_data(type, xpath, options = {}, callbacks = DataCycleCore::Callbacks.new)
      Mongoid.override_database("#{type.database_name}_#{external_source.id}")

      callbacks.execute_callback(:preparing_phase, type.to_s.demodulize.underscore.pluralize.to_sym)

      data = endpoint.send("load_#{type.to_s.demodulize.underscore.pluralize}")

      options[:max_count] ||= data.xpath(xpath).count

      callbacks.execute_callback(:phase_started, type.to_s.demodulize.underscore.pluralize.to_sym, options[:max_count])

      item_count = 0

      begin
        data.xpath(xpath).each do |xml_data|
          item_count += 1

          begin
            item_id, item_name = yield(xml_data.to_hash)

            item = type.find_or_initialize_by('external_id': item_id)
            item.dump = xml_data.to_hash
            item.save!

            callbacks.execute_callback(:item_processed, item_name, item_id, item_count, options[:max_count])
          rescue => e
            callbacks.execute_callback(:error, item_name, item_id, data, e)
          end

          return if options[:max_count] && item_count >= options[:max_count]
        end
      ensure
        Mongoid.override_database(nil)

        callbacks.execute_callback(:phase_finished, type.to_s.demodulize.underscore.pluralize.to_sym, item_count)
      end
    end


    protected

    def endpoint
      @endpoint ||= Endpoint.new(Hash[credentials.map { |k, v| [k.to_sym, v] }])
    end
  end
end
