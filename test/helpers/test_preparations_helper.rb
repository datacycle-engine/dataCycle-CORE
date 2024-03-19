# frozen_string_literal: true

module DataCycleCore
  module TestPreparations
    CONTENT_TABLES = [:creative_works, :events, :intangibles, :media_objects, :organizations, :persons, :places, :products, :things, :users].freeze
    ASSETS_PATH = Rails.root.join('..', 'fixtures', 'files').freeze
    EXCEPTED_ATTRIBUTES =
      {
        common: ['id', 'data_pool', 'data_type', 'publication_schedule', 'date_created', 'date_modified', 'date_deleted', 'release_status_id',
                 'release_status_comment', 'subject_of', 'is_linked_to', 'linked_thing', 'externalIdentifier', 'license_classification',
                 'universal_classifications', 'slug', 'schema_types'],
        creative_work: ['image', 'quotation', 'content_location', 'tags', 'textblock', 'output_channel', 'author', 'about', 'keywords', 'topic',
                        'video', 'potential_action', 'slug', 'work_translation', 'translation_of_work'],
        event: ['event_category', 'event_tag', 'v_ticket_categories', 'v_ticket_tags', 'feratel_owners', 'feratel_locations', 'feratel_status', 'slug',
                'hrs_dd_categories', 'feratel_facilities', 'schedule', 'puglia_ticket_type', 'marche_classifications', 'puglia_category', 'puglia_type',
                'piemonte_tag', 'piemonte_scope', 'piemonte_category', 'piemonte_coverage', 'piemonte_data_source', 'open_destination_one_keywords'],
        organization: ['slug'],
        place: ['stars', 'source', 'regions', 'google_tags', 'xamoom_tags', 'feratel_types', 'feratel_locations',
                'fontend_type', 'feratel_owners', 'feratel_topics', 'holiday_themes', 'poi_categories', 'tour_categories',
                'outdoor_active_tags', 'feratel_classifications', 'accommodation_categories', 'frontend_type', 'logo', 'country_code',
                'google_business_primary_category', 'google_business_additional_categories', 'feratel_status', 'topic',
                'feratel_content_score', 'content_score', 'feratel_facilities', 'piemonte_venue_category', 'wikidata_classification',
                'feratel_creative_commons', 'additional_information', 'slug'],
        person: ['slug'],
        products: ['slug']
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
      # map classifications (Test1 mapped to Tag 1, Test2 mapped to Tag 2)
      test_alias = DataCycleCore::ClassificationAlias.find_by(name: 'Test1')
      return if test_alias.nil?
      unless test_alias.classifications.count == 2
        test_classification = DataCycleCore::Classification.find_by(name: 'Test1')
        test_classification1 = DataCycleCore::Classification.find_by(name: 'Test Veranstaltung geplant')
        test_alias.update(classification_ids: [test_classification.id, test_classification1.id])
      end
      test_alias2 = DataCycleCore::ClassificationAlias.find_by(name: 'Test2')
      return if test_alias2.nil? || test_alias2.classifications.count == 2
      test_classification2 = DataCycleCore::Classification.find_by(name: 'Test2')
      test_classification3 = DataCycleCore::Classification.find_by(name: 'Test Veranstaltung abgesagt')
      test_alias2.update(classification_ids: [test_classification2.id, test_classification3.id])
    end

    def self.load_templates(paths)
      template_importer = DataCycleCore::MasterData::Templates::TemplateImporter.new(template_paths: paths)
      template_importer.import

      template_importer.render_duplicates
      template_importer.render_mixin_errors
      template_importer.render_errors
    end

    def self.load_external_systems(paths)
      errors = DataCycleCore::MasterData::ImportExternalSystems.import_all(validation: true, paths:)

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
        password: 'PME_jeh0nek4tbf8mea',
        role_id: DataCycleCore::Role.order('rank DESC').first.id,
        confirmed_at: Time.zone.now - 1.day
      })
      @guest = DataCycleCore::User.where(email: 'guest@datacycle.at').first_or_create({
        given_name: 'Guest',
        family_name: 'User',
        password: 'vdr5pmx@juv9BMJ6ujt',
        role_id: DataCycleCore::Role.find_by(name: 'guest')&.id,
        confirmed_at: Time.zone.now - 1.day
      })
    end

    def self.create_user_group
      @test_group = DataCycleCore::UserGroup.where(name: 'TestUserGroup').first_or_create

      user_group = DataCycleCore::UserGroup.find_or_create_by!(name: 'Administrators')
      DataCycleCore::UserGroupUser.find_or_create_by!(
        user_group_id: user_group.id,
        user_id: DataCycleCore::User.find_by(email: 'admin@datacycle.at').id
      )
    end

    def self.create_content(template_name: nil, data_hash: nil, user: nil, prevent_history: false, save_time: Time.zone.now, version_name: nil, source: nil)
      return if template_name.blank? || data_hash.blank?
      data_hash = data_hash.dup.with_indifferent_access

      @content  = DataCycleCore::Thing
        .where({ template_name: })
        .where_value(data_hash.slice('given_name', 'family_name'))
        .where_translated_value(data_hash.slice('name'))
        .first

      return @content.reload if @content.present?

      @content = DataCycleCore::Thing.new(template_name:)

      return if @content.template_missing?

      @content.created_at = save_time
      @content.updated_at = save_time
      @content.created_by = user&.id if user.present?
      @content.external_key = data_hash['external_key'] if data_hash.key?('external_key')
      @content.external_source_id = data_hash['external_source_id'] if data_hash.key?('external_source_id')
      @content.save!(touch: false)

      @content.set_data_hash(
        data_hash:,
        new_content: true,
        current_user: user || User.find_by(email: 'tester@datacycle.at'),
        update_search_all: false,
        prevent_history:,
        save_time:,
        version_name:,
        source:
      )

      @content
    end

    def self.generate_schedule(dtstart, dtend, duration, frequency: 'daily', week_days: [])
      schedule = DataCycleCore::Schedule.new
      untild = dtend
      end_time = dtstart + duration if duration.present?
      untildt = DataCycleCore::Schedule.until_as_utc(untild, dtstart)
      schedule.schedule_object = IceCube::Schedule.new(dtstart, { end_time:, duration: duration&.to_i }) do |s|
        if frequency == 'daily'
          s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(dtstart.hour).until(untildt))
        elsif frequency == 'weekly'
          s.add_recurrence_rule(IceCube::Rule.weekly.until(untildt).day(week_days))
        elsif frequency == 'monthly'
          s.add_recurrence_rule(IceCube::Rule.monthly.until(untildt))
        end
      end
      schedule
    end

    def self.create_watch_list(name: nil)
      return if name.blank?

      DataCycleCore::WatchList.find_or_create_by(full_path: name, user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id) do |wl|
        wl.api = true
      end
    end

    def self.excepted_attributes(model = nil)
      return EXCEPTED_ATTRIBUTES[:common] + EXCEPTED_ATTRIBUTES[model.to_sym] if model.present?
      EXCEPTED_ATTRIBUTES[:common]
    end

    def self.load_dummy_data_hash(model, name)
      @dummy_data_hash.dig(model.to_sym, name.to_sym).dup
    end
  end
end
