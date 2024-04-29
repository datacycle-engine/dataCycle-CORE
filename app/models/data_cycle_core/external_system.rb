# frozen_string_literal: true

module DataCycleCore
  class ExternalSystem < ApplicationRecord
    attribute :last_import_time, :interval
    attribute :last_successful_import_time, :interval
    attribute :last_download_time, :interval
    attribute :last_successful_download_time, :interval

    has_many :external_system_syncs, dependent: :destroy

    # relations as external_system
    has_many :things, through: :external_system_syncs, source: :syncable, source_type: 'DataCycleCore::Thing'
    has_many :users, through: :external_system_syncs, source: :syncable, source_type: 'DataCycleCore::User'

    # relations as external_source
    # rubocop:disable Rails/HasManyOrHasOneDependent, Rails/InverseOf
    has_many :classifications, foreign_key: :external_source_id, inverse_of: :external_source
    has_many :classification_alias, foreign_key: :external_source_id, inverse_of: :external_source
    has_many :classification_contents, foreign_key: :external_source_id
    has_many :classification_content_histories, foreign_key: :external_source_id
    has_many :classification_groups, foreign_key: :external_source_id, inverse_of: :external_source
    has_many :classification_tree_labels, foreign_key: :external_source_id, inverse_of: :external_source
    has_many :classification_trees, foreign_key: :external_source_id, inverse_of: :external_source
    has_many :content_contents, foreign_key: :external_source_id
    has_many :content_content_histories, foreign_key: :external_source_id
    has_many :imported_things, foreign_key: :external_source_id, class_name: 'DataCycleCore::Thing', inverse_of: :external_source
    has_many :thing_histories, foreign_key: :external_source_id, class_name: 'DataCycleCore::Thing::History', inverse_of: :external_source
    has_many :schedules, foreign_key: :external_source_id, inverse_of: :external_source
    # rubocop:enable Rails/HasManyOrHasOneDependent, Rails/InverseOf

    scope :by_names_or_identifiers, ->(value) { where('identifier IN (:value) OR name IN (:value)', value:) }

    validates :name, presence: true

    def name_with_types
      nwt = name
      type = []
      type += ['import'] if import_config.present?
      type += ['export'] if export_config.present?
      type += ['sync'] if import_config.blank? && export_config.blank?
      nwt += " [#{type.join(', ')}]" if type.present?
      nwt
    end

    def export_config
      return @export_config if defined? @export_config
      @export_config = config&.dig('export_config')&.symbolize_keys
    end

    def refresh_config
      return @refresh_config if defined? @refresh_config
      @refresh_config = config&.dig('refresh_config')&.symbolize_keys
    end

    def download_config
      return @download_config if defined? @download_config
      @download_config = config&.dig('download_config')&.symbolize_keys
    end

    def download_list
      return @download_list if defined? @download_list
      @download_list = download_config&.sort_by { |v| v.second['sorting'] }&.map { |k, _| k.to_sym }
    end

    def download_list_ranked
      return @download_list_ranked if defined? @download_list_ranked
      @download_list_ranked = download_config&.sort_by { |v| v.second['sorting'] }&.map { |k, v| [v.dig('sorting'), k.to_sym] }
    end

    def download_pretty_list
      return @download_pretty_list if defined? @download_pretty_list
      @download_pretty_list = download_list_ranked
        &.map { |sorting, name| "#{sorting.to_s.ljust(4)}:#{name.to_sym}" }
    end

    def import_config
      return @import_config if defined? @import_config
      @import_config = config&.dig('import_config')&.symbolize_keys
    end

    def import_list
      return @import_list if defined? @import_list
      @import_list = import_config&.sort_by { |v| v.second['sorting'] }&.map { |k, _| k.to_sym }
    end

    def import_list_ranked
      return @import_list_ranked if defined? @import_list_ranked
      @import_list_ranked = import_config&.sort_by { |v| v.second['sorting'] }&.map { |k, v| [v.dig('sorting'), k.to_sym] }
    end

    def import_pretty_list
      return @import_pretty_list if defined? @import_pretty_list
      @import_pretty_list = import_list_ranked
        &.map { |sorting, name| "#{sorting.to_s.ljust(4)}:#{name.to_sym}" }
    end

    def export_config_by_filter_key(method_name, key)
      export_config&.dig(method_name.to_sym, 'filter', key) || export_config&.dig(:filter, key)
    end

    def full_options(name, type = 'import', options = {})
      (default_options(type) || {})
        .deep_symbolize_keys
        .deep_merge({ type.to_sym => send("#{type}_config").dig(name).merge({ name: name.to_s }).deep_symbolize_keys.except(:sorting) })
        .deep_merge(options.deep_symbolize_keys)
    end

    def credentials(type = 'import')
      @credentials ||= Hash.new do |h, key|
        next h[key] = self[:credentials] unless self[:credentials].is_a?(Hash)
        t_credentials = self[:credentials].dig(key) || {}
        next h[key] = t_credentials if t_credentials.is_a?(Array)
        h[key] = self[:credentials].merge(t_credentials)&.except('import', 'export')
      end
      @credentials[type.to_s]
    end

    def default_options(type = 'import')
      @default_options ||= Hash.new do |h, key|
        next h[key] = self[:default_options] unless self[:default_options].is_a?(Hash)
        h[key] = self[:default_options].merge(self[:default_options].dig(key) || {}).except('import', 'export')
      end
      @default_options[type.to_s]
    end

    def refresh(options = {})
      raise "Missing refresh_strategy for #{name}, options given: #{options}" if refresh_config.dig(:strategy).blank?
      utility_object = DataCycleCore::Export::RefreshObject.new(external_system: self)
      refresh_config.dig(:strategy).constantize.process(utility_object:, options:)
    end

    def download(options = {}, &)
      raise 'First parameter has to be an options hash!' unless options.is_a?(::Hash)
      success = true
      ts_start = Time.zone.now
      skip_save = options.delete(:skip_save)
      self.last_download = ts_start
      save if skip_save.blank?
      download_config.sort_by { |v|
        v.second['sorting']
      }.each do |(name, _)|
        success &&= download_single(name, options, &)
      end
      ts_after = Time.zone.now
      self.last_download_time = ts_after - ts_start
      if success
        self.last_successful_download = ts_start
        self.last_successful_download_time = ts_after - ts_start
      end
      save if skip_save.blank?
      success
    end

    def download_range(options = {}, &)
      raise 'First parameter has to be an options hash!' unless options.is_a?(::Hash)
      success = true
      max_sorting = download_config.map { |_name, data| data.dig('sorting') }.max
      min = options.dig(:min) || 0
      max = options.dig(:max) || max_sorting + 1
      download_config.select { |_key, hash|
        hash.dig('sorting').in?((min..max))
      }.sort_by { |v|
        v.second['sorting']
      }.each do |(name, _data)|
        success &&= download_single(name, options, &)
      end
      success
    end

    def download_single(name, options = {})
      raise "unknown downloader name: #{name}" if download_config.dig(name).blank?
      success = true
      full_options = full_options(name, 'download', options)
      locales = full_options.dig(:download, :locales) || full_options.dig(:locales) || I18n.available_locales
      raise "Missing download_strategy for #{name}, options given: #{options}" if full_options.dig(:download, :download_strategy).blank?

      cred = credentials
      cred = cred[full_options[:credentials_index]] if full_options[:credentials_index].present?
      if cred.is_a?(Hash)
        utility_object = DataCycleCore::Generic::DownloadObject.new(**full_options.merge(external_source: self, locales:, credentials: cred))
        success &&= full_options.dig(:download, :download_strategy).constantize.download_content(utility_object:, options: full_options.merge(locales:).deep_symbolize_keys)
      else
        cred.each do |credential|
          utility_object = DataCycleCore::Generic::DownloadObject.new(**full_options.merge(external_source: self, locales:, credentials: credential))
          success &&= full_options.dig(:download, :download_strategy).constantize.download_content(utility_object:, options: full_options.merge(locales:).deep_symbolize_keys)
        end
      end
      success
    end
    alias single_download download_single

    def import(options = {}, &)
      raise 'First parameter has to be an options Hash!' unless options.is_a?(::Hash)
      ts_start = Time.zone.now
      self.last_import = ts_start
      save
      import_config.sort_by { |v|
        v.second['sorting']
      }.each do |(name, _)|
        self.last_import_time = Time.zone.now - ts_start
        save
        import_single(name, options, &)
        self.last_import_time = Time.zone.now - ts_start
        save
      end
      self.last_successful_import = ts_start
      self.last_successful_import_time = Time.zone.now - ts_start
      save
    end

    def import_range(options = {}, &)
      raise 'First parameter has to be an options Hash!' unless options.is_a?(::Hash)
      max_sorting = import_config.map { |_name, data| data.dig('sorting') }.max
      min = options.dig(:min) || 0
      max = options.dig(:max) || max_sorting + 1
      import_config.select { |_key, hash|
        hash.dig('sorting').in?((min..max))
      }.sort_by { |v|
        v.second['sorting']
      }.each do |(name, _)|
        import_single(name, options, &)
      end
    end

    def import_single(name, options = {})
      raise "unknown importer name: #{name}" if import_config.dig(name).blank?
      full_options = full_options(name, 'import', options)
      locales = full_options[:import][:locales] || full_options[:locales] || I18n.available_locales
      utility_object = DataCycleCore::Generic::ImportObject.new(**full_options.merge(external_source: self, locales:))
      raise "Missing import_strategy for #{name}, options given: #{options}" if full_options.dig(:import, :import_strategy).blank?
      full_options.dig(:import, :import_strategy).constantize.import_data(utility_object:, options: full_options.merge(locales:).deep_symbolize_keys)
    end
    alias single_import import_single

    def import_one(name, external_key, options = {}, mode = 'full')
      raise 'no external key given' if external_key.blank?
      import_single(name, options.deep_merge({ mode:, import: { source_filter: { external_id: external_key } } }))
    end

    def collections
      mongo_database = "#{Generic::Collection.database_name}_#{id}"
      Mongoid.override_database(mongo_database)
      Mongoid.clients[id] = {
        'database' => mongo_database,
        'hosts' => Mongoid.default_client.cluster.servers.map(&:address).map { |adr| "#{adr.host}:#{adr.port}" },
        'options' => nil
      }
      OpenStruct.new(Mongoid.client(id).collections.index_by(&:name))
    end

    def collection(name)
      mongo_database = "#{Generic::Collection.database_name}_#{id}"
      Mongoid.override_database(mongo_database)
      Mongoid.clients[id] = {
        'database' => mongo_database,
        'hosts' => Mongoid.default_client.cluster.servers.map(&:address).map { |adr| "#{adr.host}:#{adr.port}" },
        'options' => nil
      }
      yield(Mongoid.client(id)[name])
    ensure
      Mongoid.override_database(nil)
    end

    def database_name
      "#{Generic::Collection.database_name}_#{id}"
    end

    def reset(time = nil)
      update!(last_import: time, last_successful_import: time, last_download: time, last_successful_download: time)
      reload
    end

    def external_url(content)
      return if default_options&.dig('external_url').blank? || content&.external_key.blank?

      format(default_options.dig('external_url'), locale: I18n.locale, external_key: content.external_key)
    end

    def external_detail_url(content)
      return if default_options&.dig('external_detail_url').blank? || content&.external_key.blank?

      format(default_options.dig('external_detail_url'), locale: I18n.locale, external_key: content.external_key)
    end

    def self.find_from_hash(data)
      return find_by(identifier: data['identifier']) if data['identifier'].present?

      find_by(identifier: data['name']) || find_by(name: data['name'])
    end

    def query(collection_name, &)
      mongo_class = Mongoid::PersistenceContext.new(DataCycleCore::Generic::Collection, collection: collection_name)
      db_name = mongo_class.database_name.to_s
      db_name = "#{db_name}_#{id}" unless db_name.split('_').last == id
      Mongoid.override_database(db_name)
      DataCycleCore::Generic::Collection.with(mongo_class, &)
    ensure
      Mongoid.override_database(nil)
    end

    def query2(collection_name, &)
      mongo_class = Mongoid::PersistenceContext.new(DataCycleCore::Generic::Collection, collection: collection_name)
      db_name = mongo_class.database_name.to_s
      db_name = "#{db_name}_#{id}" unless db_name.split('_').last == id
      Mongoid.override_database(db_name)
      DataCycleCore::Generic::Collection2.with(mongo_class, &)
    ensure
      Mongoid.override_database(nil)
    end

    def destroy_all(collection_name)
      mongo_class = Mongoid::PersistenceContext.new(DataCycleCore::Generic::Collection, collection: collection_name)
      Mongoid.override_database("#{mongo_class.database_name}_#{id}")
      DataCycleCore::Generic::Collection.with(mongo_class, &:destroy_all)
    ensure
      Mongoid.override_database(nil)
    end

    def maintenance(collection_name)
      mongo_class = Mongoid::PersistenceContext.new(DataCycleCore::Generic::Collection, collection: collection_name)
      Mongoid.override_database("#{mongo_class.database_name}_#{id}")
      DataCycleCore::Generic::Collection.with(mongo_class) do |mongo_collection|
        mongo_collection.where({ 'dump.de.deleted_at': { '$exists' => true }, 'dump.en.deleted_at': { '$exists' => false } }).find_all do |item|
          item.dump['en']['archived_at'] = item.dump['de']['archived_at'] if item.dump['de']['archived_at'].present?
          item.dump['en']['last_seen_before_archived'] = item.dump['de']['last_seen_before_archived'] if item.dump['de']['last_seen_before_archived'].present?
          item.dump['en']['archive_reason'] = item.dump['de']['archive_reason'] if item.dump['de']['archive_reason'].present?
          item.dump['en']['deleted_at'] = item.dump['de']['deleted_at'] if item.dump['de']['deleted_at'].present?
          item.dump['en']['last_seen_before_delete'] = item.dump['de']['last_seen_before_delete'] if item.dump['de']['last_seen_before_delete'].present?
          item.dump['en']['delete_reason'] = item.dump['de']['delete_reason'] if item.dump['de']['delete_reason'].present?
          item.save!
        end
      end
    ensure
      Mongoid.override_database(nil)
    end

    def config?(key)
      config&.dig(key).present?
    end

    def import_module?
      config?('import_config')
    end

    def export_module?
      config?('export_config')
    end

    def webhook_module?
      config?('api_strategy')
    end

    def service_module?
      config.blank? && credentials.present?
    end

    def foreign_module?
      !import_module? &&
        !export_module? &&
        !webhook_module? &&
        !service_module?
    end

    def self.grouped_by_type(additional_properties = {})
      external_systems = order(name: :asc).to_a

      {
        import: external_systems.filter { |v| v.import_module? || v.webhook_module? }
          .as_json(only: [:id, :name])
          .map { |es| es.with_indifferent_access.merge(additional_properties&.dig(es['id']) || { webhook_only: true }) }
          .sort_by { |v| [v[:deactivated] ? 1 : 0, v[:webhook_only] ? 1 : 0, v[:name].downcase] },
        export: external_systems.filter(&:export_module?).as_json(only: [:id, :name]),
        service: external_systems.filter(&:service_module?).as_json(only: [:id, :name]),
        foreign: external_systems.filter(&:foreign_module?).as_json(only: [:id, :name])
      }.with_indifferent_access
    end
  end
end
