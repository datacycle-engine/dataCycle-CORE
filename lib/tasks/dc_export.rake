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

      query = filter.apply(watch_list:)
      query = query.watch_list_id(watch_list.id) unless watch_list.nil?
      contents = query.query.page(1).per(query.query.size)

      logger = Logger.new('log/dc_export_endpoint_jsonld.log')

      dir = Rails.public_path.join('uploads', 'export')
      dir = dir.join(*folder_path) if folder_path.present?
      FileUtils.mkdir_p(dir)

      renderer = DataCycleCore::Api::V4::ContentsController.renderer.new(
        http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
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

      size = contents.total_count
      queue = DataCycleCore::WorkerPool.new(ActiveRecord::Base.connection_pool.size - 1)
      progress = ProgressBar.create(total: size, format: '%t |%w>%i| %a - %c/%C', title: endpoint.id)
      json_data = []

      contents.find_each do |item|
        queue.append do
          logger.info("[START PROCESSING] for THING ID: #{item.id} / endpoint: #{endpoint.id}")
          data = Rails.cache.fetch(DataCycleCore::LocalizationService.view_helpers.api_v4_cache_key(item, locales, [['full', 'recursive']], []), expires_in: 1.year + Random.rand(7.days)) do
            I18n.with_locale(item.first_available_locale(locales)) do
              logger.info("[START JSON] JSON Parsing for THING ID: #{item.id} / endpoint: #{endpoint.id}")
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
                             api_context: 'api'
                           },
                           locals: {
                             content: item,
                             options: { languages: locales }
                           }
                         ))
              logger.info("[FINISHED JSON] JSON Parsing for THING ID: #{item.id} / endpoint: #{endpoint.id}")
            end
          end

          json_data.push(data.to_json)
          progress.increment
          logger.info("[FINISH PROCESSING] for THING ID: #{item.id} / endpoint: #{endpoint.id}")
        end
      end

      queue.wait!

      File.write(dir.join("#{endpoint.id}.jsonld"), result.delete_suffix(']}') + json_data.join(',') + ']}')
    end
  end
end
