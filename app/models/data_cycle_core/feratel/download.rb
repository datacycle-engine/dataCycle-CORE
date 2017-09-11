module DataCycleCore::Feratel
  class Download < DataCycleCore::Import::DownloadBase
    def download(**options, &block)
      callbacks = DataCycleCore::Callbacks.new(block)

      options[:locales] ||= I18n.available_locales.map(&:to_s).reject { |l| l.include?('-') }.map(&:to_sym)

      download_locations(callbacks, options)
      download_holiday_themes(callbacks, options)
      download_infrastructure_topics(callbacks, options)
      download_custom_attributes(callbacks, options)
      download_facility_groups(callbacks, options)
      download_facilities(callbacks, options)
      download_rating_questions(callbacks, options)
      download_infrastructure(callbacks, options)
      download_additional_service_providers(callbacks, options)
      download_events(callbacks, options)
    end

    def download_locations(callbacks = DataCycleCore::Callbacks.new, **options)
      download_data(Location,
                    ->(data) { data['Id'] },
                    ->(data) { data['Name'] },
                    callbacks,
                    options)
    end

    def download_holiday_themes(callbacks = DataCycleCore::Callbacks.new, **options)
      download_data(HolidayTheme,
                    ->(data) { data['Id'] },
                    ->(data) { [data['Name']['Translation']].flatten.first.try(:[], 'text') },
                    callbacks,
                    options)
    end

    def download_infrastructure_topics(callbacks = DataCycleCore::Callbacks.new, **options)
      download_data(InfrastructureTopic,
                    ->(data) { data['Id'] },
                    ->(data) { [data['Name']['Translation']].flatten.first.try(:[], 'text') },
                    callbacks,
                    options)
    end

    def download_custom_attributes(callbacks = DataCycleCore::Callbacks.new, **options)
      download_data(CustomAttribute,
                    ->(data) { data['Id'] },
                    ->(data) { data['Name'] },
                    callbacks,
                    options)
    end

    def download_facility_groups(callbacks = DataCycleCore::Callbacks.new, **options)
      download_data(FacilityGroup,
                    ->(data) { data['Id'] },
                    ->(data) { [data['Name']['Translation']].flatten.first.try(:[], 'text') },
                    callbacks,
                    options)
    end

    def download_facilities(callbacks = DataCycleCore::Callbacks.new, **options)
      download_data(Facility,
                    ->(data) { data['Id'] },
                    ->(data) { [data['Name']['Translation']].flatten.first.try(:[], 'text') },
                    callbacks,
                    options)
    end

    def download_rating_questions(callbacks = DataCycleCore::Callbacks.new, **options)
      download_data(RatingQuestion,
                    ->(data) { data['Id'] },
                    ->(data) { [data['Name']['Translation']].flatten.first.try(:[], 'text') },
                    callbacks,
                    options)
    end

    def download_infrastructure(callbacks = DataCycleCore::Callbacks.new, **options)
      download_data(InfrastructureItem,
                    ->(data) { data['Id'] },
                    ->(data) { [data['Details']['Names']['Translation']].flatten.first.try(:[], 'text') },
                    callbacks,
                    options)
    end

    def download_additional_service_providers(callbacks = DataCycleCore::Callbacks.new, **options)
      download_data(AdditionalServiceProvider,
                    ->(data) { data['Id'] },
                    ->(data) { [data['Details']['Names']['Translation']].flatten.first.try(:[], 'text') },
                    callbacks,
                    options)
    end


    def download_events(callbacks = DataCycleCore::Callbacks.new, **options)
      download_data(Event,
                    ->(data) { data['Id'] },
                    ->(data) { [data['Details']['Names']['Translation']].flatten.first.try(:[], 'text') },
                    callbacks,
                    options)
    end


    protected

    def endpoint
      @endpoint ||= Endpoint.new(Hash[credentials.map { |k, v| [k.to_sym, v] }])
    end
  end
end
