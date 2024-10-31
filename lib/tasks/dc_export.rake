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

      logger = Logger.new("log/dc_export_#{endpoint.id}_jsonld.log")

      dir = Rails.public_path.join('uploads', 'export')
      dir = dir.join(*folder_path) if folder_path.present?
      FileUtils.mkdir_p(dir)
      File.write(dir.join("#{endpoint.id}.jsonld.tmp"), '')

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

      size = contents.total_count
      queue = DataCycleCore::WorkerPool.new(ActiveRecord::Base.connection_pool.size - 1)
      progress = ProgressBar.create(total: size, format: '%t |%w>%i| %a - %c/%C', title: endpoint.id)

      logger.info("[EXPORTING] #{size} things in endpoint: #{endpoint.id}")
      puts "Exporting #{size} things in endpoint: #{endpoint.id}"

      file = File.open(dir.join("#{endpoint.id}.jsonld.tmp"), 'a')
      file << result.delete_suffix(']}')

      contents.each do |item|
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
                             api_context: 'api'
                           },
                           locals: {
                             content: item,
                             options: { languages: locales }
                           }
                         ))
            rescue SystemStackError
              raise unless retries < 5

              logger.error("[RETRYING] for thing: #{item.id} (retry: #{retries})")
              retries += 1
              retry
            end
          end

          file << ("#{data.to_json},")

          progress.increment
        end
      end

      queue.wait!

      file.truncate(file.size - 1)
      file << ']}'
      file.close

      FileUtils.rm_f(dir.join("#{endpoint.id}.jsonld"))
      File.rename(dir.join("#{endpoint.id}.jsonld.tmp"), dir.join("#{endpoint.id}.jsonld"))

      logger.info("[FINISHED EXPORT] for things in endpoint: #{endpoint.id}")
    end
  end
end
