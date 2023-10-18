# frozen_string_literal: true

namespace :dc do
  namespace :export do
    desc 'export POI'
    task poi: :environment do
      require 'csv'
      tsv = CSV.open(Rails.root.join('log', 'POI.tsv'), 'wb')
      tsv << [['#ID', 'EVENTPLACE', 'LATITUDE', 'LONGITUDE', 'STREET', 'COUNTRY', 'CITY', 'ZIP', 'COMMENT'].join("\t")]
      tsv << [['#ID', 'EVENTPLACE', 'LATITUDE', 'LONGITUDE', 'STREET', 'COUNTRY', 'CITY', 'ZIP', 'COMMENT'].join("\t")]
      DataCycleCore::Thing.where(template_name: 'POI').each do |item|
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

      query = filter.apply(watch_list: watch_list)
      query = query.watch_list_id(watch_list.id) unless watch_list.nil?
      contents = query.query

      result = DataCycleCore::Api::V4::ContentsController.renderer.new(
        http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
        https: Rails.application.config.force_ssl
      ).render_to_string(
        assigns: {
          url_parameters: {},
          include_parameters: [['full', 'recursive']],
          fields_parameters: [],
          field_filter: false,
          classification_trees_parameters: [],
          classification_trees_filter: false,
          section_parameters: { links: 0 },
          language: locales,
          api_subversion: 0,
          api_version: 4,
          contents: contents.page(1).per(contents.size),
          permitted_params: {
            section: { links: 0 }
          },
          watch_list: watch_list,
          stored_filter: stored_filter
        },
        template: 'data_cycle_core/api/v4/contents/index',
        layout: false
      )

      dir = Rails.public_path.join('uploads', 'export')
      dir = dir.join(*folder_path) if folder_path.present?
      FileUtils.mkdir_p(dir)

      File.write(dir.join("#{endpoint.id}.jsonld"), result)
    end
  end
end
