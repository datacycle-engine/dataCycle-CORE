# frozen_string_literal: true

require 'rake_helpers/parallel_helper'

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
      progressbar = ProgressBar.create(total: contents.size, title: 'Geocoder Cache Warmup')

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
      logger.info("[#{args.identifier}] Started Warmup ...")

      params = cache_config['parameters']&.symbolize_keys || {}

      if params[:contents].present?
        endpoint_id_or_slug = params[:contents]
        stored_filter = DataCycleCore::StoredFilter.by_id_or_slug(endpoint_id_or_slug).first
        watch_list = DataCycleCore::WatchList.without_my_selection.by_id_or_slug(endpoint_id_or_slug).first if stored_filter.nil?

        abort('endpoint not found!') if stored_filter.nil? && watch_list.nil?

        params[:contents] = stored_filter.nil? ? watch_list.things : stored_filter.apply.query
        contents_count = params[:contents].size
        params[:contents] = params[:contents].page(1).per(contents_count)
        logger.info("[#{args.identifier}] Warmup running for #{contents_count} contents ...")
      end

      ParallelHelper.with_asynchronous_queries_session do
        renderer = cache_config['renderer'].classify.safe_constantize&.new(**params)
        renderer.render
      end

      logger.info("[#{args.identifier}] Finished Warmup for #{args.identifier} (#{contents_count.to_i} items) in #{(Time.zone.now - tstart).round(2)}s.")
    end

    desc 'rebuild caches for all cachable collections'
    task rebuild_collection_caches: :environment do
      logger = Logger.new('log/stored_filter_cache_rebuild.log')
      tstart = Time.zone.now
      queue = DataCycleCore::WorkerPool.new
      collections = DataCycleCore::StoredFilter.with_stale_cache
      logger.info("Started Rebuilding Stored Filter Caches (#{collections.size} collections, #{queue.num_workers} workers)...")

      collections.find_each do |stored_filter|
        queue.append do
          stored_filter.rebuild_cache!
        rescue StandardError => e
          logger.error("[ERROR] Cache rebuild failed for ##{stored_filter.id}: #{e.message}")
        end
      end

      queue.wait!

      logger.info("Finished Rebuilding Stored Filter Caches in #{(Time.zone.now - tstart).round(2)}s.")
    end
  end
end
