# frozen_string_literal: true

module DataCycleCore
  module TestPreparations
    CONTENT_TABLES = [:creative_works, :events, :intangibles, :media_objects, :organizations, :persons, :places, :products, :things, :users].freeze
    ASSETS_PATH = Rails.root.join('..', 'fixtures', 'files').freeze
    EXCEPTED_ATTRIBUTES =
      {
        common: ['id', 'data_pool', 'data_type', 'publication_schedule', 'date_created', 'date_modified', 'date_deleted', 'release_status_id',
                 'release_status_comment', 'subject_of', 'is_linked_to', 'linked_thing', 'externalIdentifier', 'license_classification',
                 'universal_classifications'],
        creative_work: ['image', 'quotation', 'content_location', 'tags', 'textblock', 'output_channel', 'author', 'about', 'keywords', 'topic', 'video', 'potential_action'],
        event: ['event_category', 'event_tag', 'v_ticket_categories', 'v_ticket_tags', 'feratel_owners', 'feratel_locations', 'feratel_status',
                'hrs_dd_categories', 'feratel_facilities', 'schedule', 'puglia_ticket_type', 'marche_classifications', 'puglia_category', 'puglia_type',
                'piemonte_tag', 'piemonte_scope', 'piemonte_category', 'piemonte_coverage', 'piemonte_data_source', 'open_destination_one_keywords'],
        organization: [],
        place: ['stars', 'source', 'regions', 'google_tags', 'xamoom_tags', 'feratel_types', 'feratel_locations',
                'fontend_type', 'feratel_owners', 'feratel_topics', 'holiday_themes', 'poi_categories', 'tour_categories',
                'outdoor_active_tags', 'feratel_classifications', 'accommodation_categories', 'frontend_type', 'logo', 'country_code',
                'google_business_primary_category', 'google_business_additional_categories', 'feratel_status', 'topic',
                'feratel_content_score', 'feratel_facilities', 'piemonte_venue_category', 'wikidata_classification',
                'feratel_creative_commons'],
        person: [],
        products: []
      }.freeze

    @dummy_data_hash =
      {
        creative_works: {},
        events: {},
        intangibles: {},
        media_objects: {},
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

    def self.load_external_systems(paths)
      errors = DataCycleCore::MasterData::ImportExternalSystems.import_all(validation: true, paths: paths)

      return if errors.blank?

      puts 'the following errors were encountered during import:'
      ap errors
    end

    def self.load_dummy_data(paths)
      paths.each do |path|
        CONTENT_TABLES.each do |content_table_name|
          files = path + content_table_name.to_s + '*.json'

          file_names = Dir[files]
          file_names.each do |file_name|
            file_base_name = File.basename(file_name, '.json')
            json_data = JSON.parse(ERB.new(File.read(file_name)).result)
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
        role_id: DataCycleCore::Role.order('rank DESC').first.id,
        confirmed_at: Time.zone.now - 1.day
      })
      @guest = DataCycleCore::User.where(email: 'guest@datacycle.at').first_or_create({
        given_name: 'Guest',
        family_name: 'User',
        password: 'PdebUfWF9aab2KG6',
        role_id: DataCycleCore::Role.find_by(name: 'guest')&.id,
        confirmed_at: Time.zone.now - 1.day
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

    def self.create_content(template_name: nil, data_hash: nil, user: nil, prevent_history: false, save_time: Time.zone.now)
      return if template_name.blank? || data_hash.blank?
      data_hash = data_hash.dup.with_indifferent_access
      @content = DataCycleCore::Thing.find_by(data_hash.slice('name', 'given_name', 'family_name').merge({ template_name: template_name, template: false }))
      return @content if @content.present?

      @content = DataCycleCore::Thing.find_by(template_name: template_name, template: true).dup
      @content.template = false
      @content.created_at = save_time - 1 / 1001.0 # use - 1 / 1001.0 to ensure history creation
      @content.updated_at = save_time - 1 / 1001.0 # use - 1 / 1001.0 to ensure history creation
      @content.created_by = user&.id if user.present?
      @content.save!

      valid = @content.set_data_hash(data_hash: data_hash, new_content: true, current_user: (user || User.find_by(email: 'tester@datacycle.at')), update_search_all: false, prevent_history: prevent_history, save_time: save_time)
      valid[:error].each { |k, v| v.each { |e| @content.errors.add(k, e) } } if valid[:error].present?

      @content
    end

    def self.generate_schedule(dtstart, dtend, duration)
      schedule = DataCycleCore::Schedule.new
      dtstart = dtstart
      dtend = dtend
      end_time = dtstart + duration
      schedule.schedule_object = IceCube::Schedule.new(dtstart, { end_time: end_time, duration: duration.to_i }) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(dtstart.hour).until(dtend))
      end
      schedule
    end

    def self.create_watch_list(name: nil)
      return if name.blank?

      DataCycleCore::WatchList.find_or_create_by(full_path: name, user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id)
    end

    def self.excepted_attributes(model = nil)
      return EXCEPTED_ATTRIBUTES[:common] + EXCEPTED_ATTRIBUTES[model.to_sym] if model.present?
      EXCEPTED_ATTRIBUTES[:common]
    end

    def self.load_dummy_data_hash(model, name)
      @dummy_data_hash.dig(model.to_sym, name.to_sym).dup
    end

    # def self.data_set_object(template_name)
    #   template = DataCycleCore::Thing.where(template: true, template_name: template_name).first
    #   data_set = DataCycleCore::Thing.new
    #   data_set.schema = template.schema
    #   data_set.template_name = template.template_name
    #   data_set
    # end
  end
end
