# frozen_string_literal: true

namespace :dc do
  namespace :cache do
    desc 'basic cache warmup (for api_v4)'
    task warm_up: :environment do
      session = ActionDispatch::Integration::Session.new(Rails.application)
      api_stored_filter = DataCycleCore::StoredFilter.where(api: true)
      api_token = DataCycleCore::User.find_by(email: 'admin@datacycle.at').access_token
      api_stored_filter.each do |filter|
        puts "loading endpoint: #{filter.name} #{filter.id} (page 1)"
        session.get("/api/v4/endpoints/#{filter.id}?token=#{api_token}")
        json_data = JSON.parse(session.response.body)
        pages = json_data.dig('meta', 'pages').to_i
        (2..pages).to_a.each do |page|
          break if page > 10
          puts "loading endpoint: #{filter.name} #{filter.id} (page #{page})"
          session.get("/api/v4/endpoints/#{filter.id}?token=#{api_token}&page[number]=#{page}")
        end
      end
    end

    desc 'clear rails cache'
    task clear_rails_cache: :environment do
      Rails.cache.clear
    end

    desc 'cache warmup for geocoder'
    task :warm_up_geocoder, [:endpoint_id_or_slug] => :environment do |_, args|
      abort('feature disabled!') unless DataCycleCore::Feature['Geocode']&.enabled?
      abort('endpoint missing!') if args.endpoint_id_or_slug.blank?

      logger = Logger.new('log/geocoder_cache_warmup.log')
      logger.info('Started Warmup...')
      stored_filter = DataCycleCore::StoredFilter.by_id_or_slug(args.endpoint_id_or_slug).first
      watch_list = DataCycleCore::WatchList.without_my_selection.by_id_or_slug(args.endpoint_id_or_slug).first if stored_filter.nil?

      abort('endpoint not found!') if stored_filter.nil? && watch_list.nil?

      contents = stored_filter.nil? ? watch_list.things : stored_filter.apply.query
      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'Geocoder Cache Warmup')

      contents.find_each do |content|
        I18n.with_locale(content.first_available_locale) do
          address_hash = content.try(DataCycleCore::Feature['Geocode'].address_source(content)).to_h
          location = content.try(DataCycleCore::Feature['Geocode'].target_key(content))

          next progressbar.increment unless location.present? && address_hash.values_at('postal_code', 'street_address', 'address_locality').all?(&:present?)

          geocode_cache_key = DataCycleCore::Feature['Geocode'].geocode_cache_key(address_hash)
          Rails.cache.write(geocode_cache_key, location, expires_in: 7.days) unless Rails.cache.exist?(geocode_cache_key)

          reverse_geocode_cache_key = DataCycleCore::Feature['Geocode'].reverse_geocode_cache_key(location)
          Rails.cache.write(reverse_geocode_cache_key, address_hash, expires_in: 7.days) unless Rails.cache.exist?(reverse_geocode_cache_key)

          progressbar.increment
        end
      end

      logger.info("[DONE] Finished Warmup (#{contents.size} Contents).")
    end

    desc 'cache warmup for endpoint in cache_warmup.yml'
    task :warm_up_endpoint, [:identifier] => :environment do |_, args|
      abort('identifier missing!') if args.identifier.blank?
      abort("config missing for identifier: #{args.identifier}") unless DataCycleCore.cache_warmup&.key?(args.identifier)

      cache_config = DataCycleCore.cache_warmup[args.identifier]
      tstart = Time.zone.now
      logger = Logger.new('log/cache_warmup.log')
      logger.info("Started Warmup for #{args.identifier} ...")

      params = cache_config['parameters']&.symbolize_keys || {}

      if params[:contents].present?
        endpoint_id_or_slug = params[:contents]
        stored_filter = DataCycleCore::StoredFilter.by_id_or_slug(endpoint_id_or_slug).first
        watch_list = DataCycleCore::WatchList.without_my_selection.by_id_or_slug(endpoint_id_or_slug).first if stored_filter.nil?

        abort('endpoint not found!') if stored_filter.nil? && watch_list.nil?

        params[:contents] = stored_filter.nil? ? watch_list.things : stored_filter.apply.query
        contents_count = params[:contents].size
        params[:contents] = params[:contents].page(1).per(contents_count)
      end

      renderer = cache_config['renderer'].classify.safe_constantize&.new(**params)
      renderer.render

      logger.info("[DONE] Finished Warmup for #{args.identifier} (#{contents_count.to_i} items) in #{(Time.zone.now - tstart).round(2)}s.")
    end
  end
end
