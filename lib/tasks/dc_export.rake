# frozen_string_literal: true

namespace :dc do
  namespace :export do
    desc 'export POI'
    task poi: :environment do
      require 'csv'
      tsv = CSV.open(Rails.root.join('log', 'POI.tsv'), 'wb')
      tsv << [['#ID', 'EVENTPLACE', 'LATITUDE', 'LONGITUDE', 'STREET', 'COUNTRY', 'CITY', 'ZIP', 'COMMENT'].join("\t")]
      tsv << [['#ID', 'EVENTPLACE', 'LATITUDE', 'LONGITUDE', 'STREET', 'COUNTRY', 'CITY', 'ZIP', 'COMMENT'].join("\t")]
      DataCycleCore::Thing.where(template_name: 'POI').find_each do |item|
        tsv << [[item.id, item.name, item.latitude.presence, item.longitude.presence, item.address.street_address.presence, item.address.address_country.presence, item.address.address_locality.presence, item.address.postal_code.presence, item.id].join("\t")]
      end
      tsv.close
    end

    desc 'export endpoint as APIv4 JSON-LD to public folder'
    task :export_endpoint_jsonld, [:endpoint_id_or_slug, :locales, :folder_path] => :environment do |_, args|
      abort('endpoint missing!') if args.endpoint_id_or_slug.blank?
      folder_path = args.folder_path.to_s.split('|').map(&:strip)
      locales = (args.locales.presence || 'de').split('|').map(&:strip)

      stored_filter = DataCycleCore::StoredFilter.by_id_or_slug(args.endpoint_id_or_slug).first
      watch_list = DataCycleCore::WatchList.without_my_selection.by_id_or_slug(args.endpoint_id_or_slug).first if stored_filter.nil?
      endpoint = stored_filter || watch_list

      abort('endpoint not found!') if endpoint.nil?

      filter = stored_filter || DataCycleCore::StoredFilter.new
      filter.language = locales
      linked_stored_filter = endpoint.linked_stored_filter.cached if endpoint.linked_stored_filter_id.present?

      # match the APIv4 base search (see FilterConcern#build_search_query): `.cached` resolves membership
      # from the endpoint's precomputed cache (stored_filter_caches, a fast EXISTS) when it is enabled and
      # fresh, and transparently falls back to the live query otherwise - so the export mirrors what the API
      # serves and skips recomputing the full filter on every run for cachable endpoints.
      query = filter.cached.apply(watch_list:)
      query = query.watch_list_id(watch_list.id) unless watch_list.nil?
      thing_ids = ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
        ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')
        query.query.pluck(:id)
      end
      size = thing_ids.size

      logger = Logger.new('log/dc_export_jsonld.log')
      start_time = Time.zone.now

      # [C] Memory management for glibc. This task renders `full.recursive` graphs for thousands of
      # things across several worker threads, churning tens of thousands of transient objects per item.
      # Under glibc, freed memory is retained in per-thread arena free lists (up to 8*CPU arenas by
      # default) and is NOT handed back to the OS on GC alone - so RSS climbs into multiple GB even
      # though the live Ruby heap stays flat (measured: live slots flat, RSS 700MB->1GB+ and rising).
      # Cap the arenas (set before the worker threads spawn) and call malloc_trim after freeing to
      # return the pages to the OS. Both degrade to a no-op on non-glibc allocators (macOS / jemalloc /
      # tcmalloc): the symbols are simply absent, so `release_memory` falls back to a plain GC.start.
      malloc_trim = nil
      begin
        require 'fiddle'
        libc = Fiddle.dlopen(nil)
        Fiddle::Function.new(libc['mallopt'], [Fiddle::TYPE_INT, Fiddle::TYPE_INT], Fiddle::TYPE_INT)
          .call(-8, ENV.fetch('DC_EXPORT_JSONLD_ARENA_MAX', 2).to_i) # -8 == M_ARENA_MAX
        trim = Fiddle::Function.new(libc['malloc_trim'], [Fiddle::TYPE_SIZE_T], Fiddle::TYPE_INT)
        malloc_trim = -> { trim.call(0) }
      rescue StandardError => e
        logger.info("[MEMORY][#{endpoint.id}] arena cap / malloc_trim unavailable (#{e.class}); using GC.start only")
      end
      release_memory = lambda do
        GC.start
        malloc_trim&.call
      end

      dir = Rails.public_path.join('uploads', 'export')
      dir = dir.join(*folder_path) if folder_path.present?
      FileUtils.mkdir_p(dir)
      filepath = dir.join("#{endpoint.id}.jsonld.tmp")
      finalpath = dir.join("#{endpoint.id}.jsonld")
      fingerprintpath = dir.join("#{endpoint.id}.jsonld.fingerprint")

      # [B] Skip the whole export when nothing that affects the output has changed since the last run.
      # The per-item render cache key is (id, updated_at, cache_valid_since) plus a constant config hash,
      # so a digest over those three columns across the full result set - combined with the render config -
      # captures every change that could alter the file (membership, content edits, config, locale, linked filter).
      data_fingerprint = DataCycleCore::Thing.where(id: thing_ids).pick(
        Arel.sql("md5(coalesce(string_agg(id::text || ':' || coalesce(updated_at::text, '') || ':' || coalesce(cache_valid_since::text, ''), ',' ORDER BY id), ''))")
      )
      config_fingerprint = Digest::MD5.hexdigest(
        [locales, 'full.recursive', 4, endpoint.updated_at, watch_list&.updated_at, linked_stored_filter&.updated_at].join('/')
      )
      fingerprint = "#{size}-#{data_fingerprint}-#{config_fingerprint}"

      if File.exist?(finalpath) && File.exist?(fingerprintpath) && File.read(fingerprintpath).strip == fingerprint
        logger.info("[SKIPPED][#{endpoint.id}] unchanged (#{size} things) after #{Time.zone.now - start_time}s")
        release_memory.call
        next
      end

      contents = DataCycleCore::Thing.where(id: thing_ids).page(1).per([size, 1].max)
      helpers = DataCycleCore::LocalizationService.view_helpers
      global_retries = 0

      begin
        renderer = DataCycleCore::Api::V4::ContentsController.renderer.new(
          http_host: Rails.application.config.action_mailer.default_url_options[:host],
          https: Rails.application.config.force_ssl
        )

        context = renderer.render_to_string(
          template: 'data_cycle_core/api/v4/api_base/_context',
          layout: false,
          assigns: {
            permitted_params: { section: { links: 0 } },
            expand_language: false
          },
          locals: {
            languages: locales
          }
        )

        meta = renderer.render_to_string(
          template: 'data_cycle_core/api/v4/api_base/_pagination_links',
          layout: false,
          assigns: {
            permitted_params: { section: { links: 0 } },
            watch_list:,
            stored_filter:
          },
          locals: {
            objects: contents
          }
        )

        result = {
          **JSON.parse(context),
          **JSON.parse(meta),
          '@graph' => []
        }.to_json

        # cap the render threads (default derives from the connection pool size) so a large pool
        # can't overload the server now that endpoints run in-process rather than in forked children
        num_workers = [DataCycleCore::WorkerPool.default_num_workers - 1, 5].min
        cache_options = { expires_in: 1.year + Random.rand(7.days) }

        logger.info("[EXPORTING][#{endpoint.id}] #{size} things in endpoint - (#{num_workers} Threads)")
        FileUtils.rm_f(filepath)
        File.write(filepath, result.delete_suffix(']}'), mode: 'a')

        # jb renders compact JSON that is byte-identical to a JSON.parse(...).to_json round-trip
        # (verified across the endpoint), so write the rendered string straight to disk/cache and skip
        # the per-item parse + re-serialize. That round-trip rebuilt the full object graph for every
        # item - ~37% of the transient allocations per item (measured) - which was the dominant churn
        # feeding GC pressure and the allocator fragmentation addressed in [C]. Caching the string (not
        # a Hash) also lets cache hits skip both the deserialize and the re-serialize.
        render_item = lambda do |item|
          retries = 1
          I18n.with_locale(item.first_available_locale(locales)) do
            renderer.render_to_string(
              template: 'data_cycle_core/api/v4/api_base/_content_details',
              layout: false,
              assigns: {
                url_parameters: {},
                include_parameters: [['full', 'recursive']],
                fields_parameters: [],
                field_filter: false,
                classification_trees_parameters: [],
                classification_trees_filter: false,
                section_parameters: { links: 0 },
                language: locales,
                api_subversion: nil,
                api_version: 4,
                contents:,
                permitted_params: { section: { links: 0 } },
                watch_list:,
                stored_filter:,
                api_context: 'api',
                linked_stored_filter:
              },
              locals: {
                content: item,
                options: { languages: locales }
              }
            )
          rescue SystemStackError, ActiveRecord::ConnectionTimeoutError => e
            unless retries < 3
              logger.error("[ERROR][#{endpoint.id}] for thing: #{item.id}")
              logger.error("[ERROR][#{endpoint.id}] Error: #{e.message}\n#{e.backtrace.first(10).join("\n")}")

              raise
            end

            logger.info("[RETRYING][#{endpoint.id}] for thing: #{item.id} (retry: #{retries})")
            retries += 1
            retry
          end
        end

        # [D] Stream in bounded batches. Since [E] loads each miss fresh inside its worker, peak RAM is
        # driven by concurrency (num_workers hydrated graphs), NOT batch_size - so batch_size now only
        # sizes the Redis round-trip and the in-flight rendered-string buffer, both cheap. Env-tunable
        # (DC_EXPORT_JSONLD_BATCH_SIZE, default 100).
        # [A] One Redis MGET per batch for the reads and one pipelined write for the freshly rendered
        # misses, instead of a round-trip per item (the dominant cost when most items are already cached).
        batch_size = ENV.fetch('DC_EXPORT_JSONLD_BATCH_SIZE', 100).to_i.clamp(1, 1000)

        # Append straight to one open handle, one write per item, so we never build the whole batch as a
        # single joined string (that concatenation plus its interpolated copy doubled the batch payload
        # in RAM - wasteful especially on the common all-cache-hit path).
        processed = 0
        File.open(filepath, 'a') do |file|
          thing_ids.each_slice(batch_size) do |id_slice|
            # Compute cache keys from bare `things` rows (id/updated_at/cache_valid_since - no associations),
            # then release them before rendering. read_multi still issues one MGET per `batch_size` keys.
            items = DataCycleCore::Thing.where(id: id_slice).to_a
            keys_by_id = items.to_h { |item| [item.id, helpers.api_v4_cache_key(item, locales, [['full', 'recursive']], [])] }
            cached = Rails.cache.read_multi(*keys_by_id.values)
            miss_ids = id_slice.reject { |id| cached.key?(keys_by_id[id]) }
            items.clear # drop the bare rows; each miss is reloaded fresh inside its worker below

            # [E] Bound the render working set to ~num_workers hydrated graphs instead of the whole batch.
            # Each worker loads its own thing, so the `full.recursive` graph it hydrates is local to the
            # block and collectible the instant the render returns. Previously all `batch_size` items were
            # held in `items` throughout the batch, so every graph the renders hydrated stayed alive until
            # the batch ended - peak RAM scaled with batch_size (100 heavy graphs => multiple GB). Now it
            # scales with concurrency. The extra per-miss `find` is one indexed PK lookup, dwarfed by the
            # render it feeds.
            fresh = Concurrent::Map.new
            queue = DataCycleCore::WorkerPool.new(num_workers)
            miss_ids.each do |id|
              key = keys_by_id[id]
              queue.append { fresh[key] = render_item.call(DataCycleCore::Thing.find(id)) }
            end
            queue.wait!

            # stream cache hits + freshly rendered misses to disk in id order, one write per item.
            # values are normalized JSON strings; `.to_json` only fires for legacy Hash entries written
            # before this change, so the cache transitions transparently without a forced rebuild.
            id_slice.each do |id|
              value = cached[keys_by_id[id]] || fresh[keys_by_id[id]]
              next if value.nil?

              file.write(value.is_a?(String) ? value : value.to_json)
              file.write(',')
            end

            unless fresh.empty?
              writes = {}
              fresh.each_pair { |k, v| writes[k] = v }
              Rails.cache.write_multi(writes, cache_options)
            end

            processed += id_slice.size
            logger.info("[SLICE][#{endpoint.id}]: #{processed}/#{size} things")

            # [C] Reclaim at every batch boundary (workers are idle here, so it never competes with a
            # render). GC.start collects the batch's transient `full.recursive` graphs and rendered
            # strings before they age into the old generation and inflate the heap; malloc_trim then
            # returns the freed pages to the OS - the step glibc skips on its own, which is what let RSS
            # climb into multiple GB. Trim without a preceding GC is nearly useless (nothing freed to
            # return), and GC without trim leaves the pages parked in glibc's arenas - both are needed.
            # A full GC over the ~flat live heap costs tens of ms against seconds of rendering per batch.
            release_memory.call
          end
        end

        File.truncate(filepath, File.size(filepath) - 1) if size.positive? # remove last comma
        File.write(filepath, ']}', mode: 'a')
        FileUtils.rm_f(finalpath)
        File.rename(filepath, finalpath)
        File.write(fingerprintpath, fingerprint) # [B] persist for the next run's skip check
      rescue StandardError => e
        unless global_retries < 3 # after 3 failed tries
          logger.error("[FAILED][#{endpoint.id}] after #{Time.zone.now - start_time}s")
          logger.error("[FAILED][#{endpoint.id}] Error: #{e.message}\n#{e.backtrace.first(10).join("\n")}")

          raise
        end

        logger.info("[RETRYING][#{endpoint.id}] retry: #{global_retries}")
        global_retries += 1
        retry
      end

      logger.info("[FINISHED][#{endpoint.id}] after #{Time.zone.now - start_time}s")
      release_memory.call
    end
  end
end
