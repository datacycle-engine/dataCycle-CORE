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

      query = filter.apply(watch_list:)
      query = query.watch_list_id(watch_list.id) unless watch_list.nil?
      thing_ids = ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
        ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')
        query.query.pluck(:id)
      end
      contents = DataCycleCore::Thing.where(id: thing_ids)
      size = contents.count
      contents = contents.page(1).per(size)

      logger = Logger.new('log/dc_export_jsonld.log')
      start_time = Time.zone.now

      dir = Rails.public_path.join('uploads', 'export')
      dir = dir.join(*folder_path) if folder_path.present?
      FileUtils.mkdir_p(dir)
      File.write(dir.join("#{endpoint.id}.jsonld.tmp"), '')
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

        queue = DataCycleCore::WorkerPool.new(DataCycleCore::WorkerPool.default_num_workers - 1)

        logger.info("[EXPORTING][#{endpoint.id}] #{size} things in endpoint - (#{queue.num_workers} Threads)")
        filepath = dir.join("#{endpoint.id}.jsonld.tmp")
        FileUtils.rm_f(filepath)
        File.write(filepath, result.delete_suffix(']}'), mode: 'a')

        contents.find_each do |item|
          queue.append do
            data = Rails.cache.fetch(DataCycleCore::LocalizationService.view_helpers.api_v4_cache_key(item, locales, [['full', 'recursive']], []), expires_in: 1.year + Random.rand(7.days)) do
              retries = 1
              I18n.with_locale(item.first_available_locale(locales)) do
                JSON.parse(renderer.render_to_string(
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
                           ))
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

            File.write(filepath, "#{data.to_json},", mode: 'a')
          end
        end

        queue.wait!

        File.truncate(filepath, File.size(filepath) - 1) # remove last comma
        File.write(filepath, ']}', mode: 'a')
        FileUtils.rm_f(dir.join("#{endpoint.id}.jsonld"))
        File.rename(dir.join("#{endpoint.id}.jsonld.tmp"), dir.join("#{endpoint.id}.jsonld"))
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
      GC.start
    end
  end
end
