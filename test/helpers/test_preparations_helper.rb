# frozen_string_literal: true

module DataCycleCore
  module TestPreparations
    CONTENT_TABLES = [:creative_works, :events, :organizations, :persons, :places, :products, :intangibles, :things, :users].freeze
    ASSETS_PATH = Rails.root.join('..', 'fixtures', 'files').freeze
    EXCEPTED_ATTRIBUTES =
      {
        common: ['id', 'data_pool', 'data_type', 'publication_schedule', 'date_created', 'date_modified', 'date_deleted', 'release_status_id', 'release_status_comment'],
        creative_work: ['image', 'quotation', 'content_location', 'tags', 'textblock', 'output_channel', 'author', 'about', 'keywords'],
        event: ['event_category', 'event_tag', 'v_ticket_categories', 'v_ticket_tags', 'feratel_owners', 'feratel_locations', 'feratel_status', 'hrs_dd_categories'],
        organization: [],
        place: ['stars', 'source', 'regions', 'google_tags', 'xamoom_tags', 'feratel_types', 'feratel_locations',
                'fontend_type', 'feratel_owners', 'feratel_topics', 'holiday_themes', 'poi_categories', 'tour_categories',
                'outdoor_active_tags', 'feratel_classifications', 'accommodation_categories', 'frontend_type', 'logo', 'country_code',
                'google_business_primary_category', 'google_business_additional_categories', 'feratel_status', 'topic'],
        person: [],
        products: []
      }.freeze

    @dummy_data_hash =
      {
        creative_works: {},
        events: {},
        intangibles: {},
        organizations: {},
        places: {},
        persons: {},
        products: {},
        things: {},
        users: {}
      }

    def self.dummy_data_hash
      @dummy_data_hash
    end

    # only for local testing
    def self.cli_options
      options = {}
      OptionParser.new { |opts|
        opts.on('-i', '--ignore_preparations') { |ignore_preparations| options[:ignore_preparations] = ignore_preparations || false }
      }.parse!
      options
    rescue StandardError
      options
    end

    def self.load_classifications(paths)
      DataCycleCore::MasterData::ImportClassifications.import_all(classification_paths: paths)
    end

    def self.load_templates(paths)
      errors, duplicates = DataCycleCore::MasterData::ImportTemplates.import_all(validation: true, template_paths: paths)
      if duplicates.present?
        puts 'INFO: the following templates had multiple definitions:'
        ap duplicates
      end
      return if errors.blank?
      puts 'the following errors were encountered during import:'
      ap errors
    end

    def self.load_external_sources(paths)
      paths.map do |path|
        errors = DataCycleCore::MasterData::ImportExternalSources.import_all(validation: true, external_source_path: path)
        next if errors.blank?
        puts 'the following errors were encountered during import:'
        ap errors
      end
    end

    def self.load_external_systems(paths)
      paths.map do |path|
        errors = DataCycleCore::MasterData::ImportExternalSystems.import_all(validation: true, external_system_path: path)
        next if errors.blank?
        puts 'the following errors were encountered during import:'
        ap errors
      end
    end

    def self.load_dummy_data(paths)
      paths.each do |path|
        CONTENT_TABLES.each do |content_table_name|
          files = path + content_table_name.to_s + '*.json'

          file_names = Dir[files]
          file_names.each do |file_name|
            file_base_name = File.basename(file_name, '.json')
            json_data = JSON.parse(File.read(file_name))
            @dummy_data_hash[content_table_name.to_sym][file_base_name.to_sym] = json_data
          end
        end
      end
    end

    def self.load_user_roles
      DataCycleCore::Role.where(rank: 0).first_or_create({ name: 'guest' })
      DataCycleCore::Role.where(rank: 1).first_or_create({ name: 'external_partner' })
      DataCycleCore::Role.where(rank: 2).first_or_create({ name: 'standard' })
      DataCycleCore::Role.where(rank: 3).first_or_create({ name: 'editor_market_office' })
      DataCycleCore::Role.where(rank: 4).first_or_create({ name: 'basic_editor' })
      DataCycleCore::Role.where(rank: 5).first_or_create({ name: 'super_editor' })
      DataCycleCore::Role.where(rank: 10).first_or_create({ name: 'admin' })
      DataCycleCore::Role.where(rank: 99).first_or_create({ name: 'super_admin' })
    end

    def self.create_users
      @admin = DataCycleCore::User.where(email: 'admin@datacycle.at').first_or_create({
        given_name: 'Administrator',
        password: '3amMQf74vp7Zpfdi',
        role_id: DataCycleCore::Role.order('rank DESC').first.id
      })
      @guest = DataCycleCore::User.where(email: 'guest@datacycle.at').first_or_create({
        given_name: 'Guest',
        family_name: 'User',
        password: 'PdebUfWF9aab2KG6',
        role_id: DataCycleCore::Role.find_by(name: 'guest')&.id
      })
    end

    def self.create_user_group
      @test_group = DataCycleCore::UserGroup.where(name: 'TestUserGroup').first_or_create

      user_group = DataCycleCore::UserGroup.find_or_create_by!(name: 'Administrators')
      # DataCycleCore::UserGroupUser.find_or_create_by!(
      #   user_group_id: user_group.id,
      #   user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id
      # )
      DataCycleCore::UserGroupUser.find_or_create_by!(
        user_group_id: user_group.id,
        user_id: DataCycleCore::User.find_by(email: 'admin@datacycle.at').id
      )
    end

    def self.create_content(template_name: nil, data_hash: nil, user: nil)
      return if template_name.blank? || data_hash.blank?
      data_hash.deep_stringify_keys!

      @content = DataCycleCore::Thing.find_by(data_hash.slice('name', 'given_name', 'family_name').merge(template_name: template_name))
      return @content if @content.present?

      @content = DataCycleCore::Thing.find_by(template_name: template_name, template: true).dup
      @content.template = false
      @content.created_by = user&.id if user.present?

      @content.save!
      I18n.with_locale(:de) do
        @content.set_data_hash(data_hash: data_hash, new_content: true, current_user: (user || User.find_by(email: 'tester@datacycle.at')))
      end
      @content.reload
    end

    def self.create_watch_list(name: nil)
      return if name.blank?

      DataCycleCore::WatchList.find_or_create_by(name: name, user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id)
    end

    def self.excepted_attributes(model = nil)
      return EXCEPTED_ATTRIBUTES[:common] + EXCEPTED_ATTRIBUTES[model.to_sym] if model.present?
      EXCEPTED_ATTRIBUTES[:common]
    end

    def self.load_dummy_data_hash(model, name)
      @dummy_data_hash.dig(model.to_sym, name.to_sym).dup
    end

    def self.data_set_object(template_name)
      template = DataCycleCore::Thing.where(template: true, template_name: template_name).first
      data_set = DataCycleCore::Thing.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set
    end
  end
end
