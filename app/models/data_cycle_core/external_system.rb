# frozen_string_literal: true

module DataCycleCore
  class ExternalSystem < ApplicationRecord
    include ExternalSystemExtensions::Import

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
      @export_config = config&.dig('export_config')&.with_indifferent_access
    end

    def refresh_config
      return @refresh_config if defined? @refresh_config
      @refresh_config = config&.dig('refresh_config')&.with_indifferent_access
    end

    def download_config
      return @download_config if defined? @download_config
      @download_config = config&.dig('download_config')&.with_indifferent_access
    end

    def import_config
      return @import_config if defined? @import_config
      @import_config = config&.dig('import_config')&.with_indifferent_access
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
        .deep_merge({ type.to_sym => send(:"#{type}_config").dig(name).merge({ name: name.to_s }).deep_symbolize_keys.except(:sorting) })
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

    def handle_import_error_notification(last_exception = nil)
    end

    def check_for_repeated_failure(type, exception = nil)
      options = default_options(type.to_sym)
      last_success = send(:"last_successful_#{type}")

      return if options.blank? || last_success.blank?
      return if options['error_notification'].blank?

      grace_period = ActiveSupport::Duration.parse(options.dig('error_notification', 'grace_period').to_s)

      return if Time.zone.now < last_success + grace_period

      error_text = "The #{type} for #{name} has been repeatedly failing for more than #{grace_period.inspect}.\n\nLast successful #{type}: #{last_success.strftime('%d.%m.%Y %H:%M')}."
      error_text += "\n\nThe last exception was: #{exception}" if exception.present?
      error = "DataCycleCore::Error::#{type.to_s.classify}::RepeatedFailureError".safe_constantize&.new(error_text)
      error.set_backtrace(exception.backtrace) if exception.present?

      return if error.nil?

      ActiveSupport::Notifications.instrument "#{type}_failed_repeatedly.datacycle", {
        exception: error,
        namespace: "repeated_failure_#{type}",
        mailing_list: options.dig('error_notification', 'emails'),
        type:,
        external_system: self
      }
    end

    def refresh(options = {})
      raise "Missing refresh_strategy for #{name}, options given: #{options}" if export_config.dig(:refresh, :strategy).blank?
      utility_object = DataCycleCore::Export::PushObject.new(
        external_system: self,
        action: :update
      )
      export_config.dig(:refresh, :strategy).safe_constantize.process(utility_object:, options:)
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
          .as_json(only: [:id, :name, :identifier])
          .map { |es| es.with_indifferent_access.merge(additional_properties&.dig(es['id']) || { webhook_only: true }) }
          .sort_by { |v| [v[:deactivated] ? 1 : 0, v[:webhook_only] ? 1 : 0, v[:name].downcase] },
        export: external_systems.filter(&:export_module?).as_json(only: [:id, :name, :identifier]),
        service: external_systems.filter(&:service_module?).as_json(only: [:id, :name, :identifier]),
        foreign: external_systems.filter(&:foreign_module?).as_json(only: [:id, :name, :identifier])
      }.with_indifferent_access
    end
  end
end
