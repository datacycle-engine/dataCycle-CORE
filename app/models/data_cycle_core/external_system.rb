# frozen_string_literal: true

module DataCycleCore
  class ExternalSystem < ApplicationRecord
    include ExternalSystemExtensions::Import
    include ExternalSystemExtensions::Status
    include ExternalSystemExtensions::UrlTemplate

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

    # The set of external systems is small and effectively static, but imports resolve them for
    # every content record (by id via the belongs_to, and by name/identifier when attaching sync
    # data). Cache the whole set indexed both ways to avoid a query per record. Invalidated on any
    # write; ExternalSystem is only ever created/updated through model callbacks (no bulk upserts).
    after_commit { DataCycleCore::ExternalSystem.reset_cache! }

    def self.cached_index
      @cached_index ||= begin
        systems = unscoped.to_a
        {
          by_id: systems.index_by(&:id).freeze,
          by_key: systems.index_by(&:identifier).merge(systems.index_by(&:name)).freeze
        }.freeze
      end
    end

    def self.cached_by_id(id)
      return if id.blank?

      cached_index[:by_id][id]
    end

    # Hash of { identifier/name => ExternalSystem } across all systems (name wins on collision,
    # matching the previous by_names_or_identifiers.index_by(&:identifier).merge(index_by(&:name))).
    def self.cached_by_key
      cached_index[:by_key]
    end

    def self.reset_cache!
      @cached_index = nil
    end

    scope :by_names_or_identifiers, ->(value) { value.blank? ? none : where(identifier: value).or(where(name: value)) }
    scope :by_names_identifiers_or_ids, lambda { |value|
      return none if value.blank?

      ids = Array.wrap(value).filter(&:uuid?)
      query = where(identifier: value).or(where(name: value))
      query = query.or(where(id: ids)) if ids.present?
      query
    }
    scope :with_import_config, -> { where("external_systems.config ->> 'import_config' IS NOT NULL") }
    scope :deactivated, -> { where(deactivated: true) }
    scope :activated, -> { where(deactivated: false) }

    before_validation :set_identifier, on: :create

    validates :name, presence: true
    validates :identifier, presence: true

    # The single system an operator addressed, by id, identifier or name. Ambiguity raises rather
    # than resolving by row order: the rake tasks reading this import into, export to and delete at
    # the system they get back, and the wrong one is not recoverable.
    # @param value [String] id, identifier or name
    # @return [DataCycleCore::ExternalSystem]
    def self.find_unique_by_names_identifiers_or_ids!(value)
      raise 'External system missing!' if value.blank?

      found = by_names_identifiers_or_ids(value).to_a

      raise "External system not found: #{value}" if found.empty?
      raise "Ambiguous external system: #{found.map(&:name).join(', ')}" if found.many?

      found.first
    end

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

    # transformation module used by the export api, e.g. Datacycle::Connector::Foo::Transformations
    # the configured constant is only accepted if it implements the export contract
    def export_transformations
      return @export_transformations if defined? @export_transformations

      transformations = export_config&.dig('transformations')&.safe_constantize
      transformations = nil unless transformations.respond_to?(:render) && transformations.respond_to?(:format)

      @export_transformations = transformations
    end

    # strategy module used to refresh exported contents, e.g. DataCycleCore::Export::Foo::Refresh
    def export_refresh_strategy
      return @export_refresh_strategy if defined? @export_refresh_strategy

      strategy = export_config&.dig('refresh', 'strategy')&.safe_constantize
      strategy = nil unless strategy.respond_to?(:process)

      @export_refresh_strategy = strategy
    end

    # when enabled, a successful delete export removes the external_system_sync link(s)
    # (for the content and its orphaned linked children) instead of keeping a 'duplicate' row
    def remove_external_system_syncs_on_delete?
      export_config&.dig('delete', 'remove_external_system_syncs') ||
        export_config&.dig('remove_external_system_syncs') || false
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

    def transformations
      return @transformations if defined? @transformations

      @transformations = config&.dig('transformations')&.with_indifferent_access
    end

    def download_list
      return @download_list if defined? @download_list

      @download_list = download_config&.sort_by { |v| v.second['sorting'] }&.map { |k, _| k.to_sym }
    end

    def download_list_ranked
      return @download_list_ranked if defined? @download_list_ranked

      @download_list_ranked = download_config&.sort_by { |v| v.second['sorting'] }&.map { |k, v| [v['sorting'], k.to_sym] }
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

      @import_list_ranked = import_config&.sort_by { |v| v.second['sorting'] }&.map { |k, v| [v['sorting'], k.to_sym] }
    end

    def import_pretty_list
      return @import_pretty_list if defined? @import_pretty_list

      @import_pretty_list = import_list_ranked
        &.map { |sorting, name| "#{sorting.to_s.ljust(4)}:#{name.to_sym}" }
    end

    def export_config_by_filter_key(method_name, key)
      export_config&.dig(method_name.to_sym, 'filter', key) || export_config&.dig(:filter, key)
    end

    # The name the export filters of an action are keyed by: strategies pass their demodulised class
    # name, which is the action only as long as the class is named after it (Export::Onlim::Update ->
    # update, Export::Onlim::ForceDelete -> force_delete). Falls back to the action for the generic
    # strategy DataCycleCore::Export::PushObject#webhook builds when none is configured.
    def export_filter_method_name(action)
      export_config&.dig(action.to_s, 'strategy')&.demodulize&.underscore || action.to_s
    end

    # #export_config_by_filter_key minus the root `filter` fallback, deliberately: the only caller is
    # dc:sync:delete, where picking up a root-level endpoints list widens a mass delete.
    def export_config_by_method_name_and_filter_key(method_name, key)
      export_config&.dig(method_name.to_sym, 'filter', key)
    end

    def step_timestamp(key, name, type)
      k = timestamp_key_for_step(name, type)
      last_import_step_time_info.dig(k, key.to_s)
    end

    def last_try(name, type)
      step_timestamp(__method__, name, type)&.in_time_zone
    end

    def last_successful_try(name, type)
      step_timestamp(__method__, name, type)&.in_time_zone
    end

    def last_try_time(name, type)
      step_timestamp(__method__, name, type)&.then { |t| ActiveSupport::Duration.build(t) }
    end

    def last_successful_try_time(name, type)
      step_timestamp(__method__, name, type)&.then { |t| ActiveSupport::Duration.build(t) }
    end

    def set_import_step_time_info(import_step = nil, values = {})
      return if import_step.blank? || values.blank?

      last_import_step_time_info[import_step] ||= {}
      last_import_step_time_info[import_step].merge!(values.stringify_keys)
      invalidate_last_download_and_import
    end

    def full_options(name, type = 'import', options = {})
      (default_options(type) || {})
        .deep_symbolize_keys
        .deep_merge({ type.to_sym => send(:"#{type}_config")[name].merge({ name: name.to_s }).deep_symbolize_keys.except(:sorting) })
        .deep_merge(options.deep_symbolize_keys)
    end

    def credentials(type = 'import')
      @credentials ||= Hash.new do |h, key|
        next h[key] = self[:credentials] unless self[:credentials].is_a?(Hash)

        t_credentials = self[:credentials][key] || {}
        next h[key] = t_credentials if t_credentials.is_a?(Array)

        h[key] = self[:credentials].merge(t_credentials)&.except('import', 'export')
      end
      @credentials[type.to_s]
    end

    def default_options(type = 'import')
      @default_options ||= Hash.new do |h, key|
        next h[key] = self[:default_options] unless self[:default_options].is_a?(Hash)

        h[key] = self[:default_options].merge(self[:default_options][key] || {}).except('import', 'export')
      end
      @default_options[type.to_s]
    end

    # Queue used to run download/import jobs for this external system, configured via the top-level
    # default_options['queue']; defaults to :importers.
    #
    # Anything that is not a known importer queue falls back to the default instead of reaching
    # +ImportJob.queue_as+ as it stands: the config contract rejects such a value, but nothing does
    # when default_options is written straight to the database, and a queue no worker listens on
    # accepts the job and then never runs it. +dc:jobs:validate+ reports the mismatch.
    # @return [Symbol]
    def import_queue
      options = self[:default_options]
      queue = options['queue'].presence&.to_sym if options.is_a?(Hash)

      queue.in?(DataCycleCore.importer_queues) ? queue : :importers
    end

    def handle_import_error_notification(last_exception = nil)
    end

    def check_for_repeated_failure(type, exception = nil, step_name = nil)
      options = default_options(type.to_sym)
      last_success = step_name.present? ? last_successful_try(step_name, type) : send(:"last_successful_#{type}")

      return if options.blank? || last_success.blank?
      return if options['error_notification'].blank?

      grace_period = ActiveSupport::Duration.parse(options.dig('error_notification', 'grace_period').to_s)

      return if Time.zone.now < last_success + grace_period

      error_text = "The #{type} for #{name} has been repeatedly failing for more than #{grace_period.inspect}.\n\nLast successful #{type}: #{last_success.strftime('%d.%m.%Y %H:%M')}."
      # same rendering as the import log — this text is what the failure mail renders verbatim
      error_text += "\n\nThe last exception was: #{DataCycleCore::Error.describe(exception)}" if exception.present?
      error = "DataCycleCore::Error::#{type.to_s.classify}::RepeatedFailureError".safe_constantize&.new(error_text)

      return if error.nil?

      error.set_backtrace(exception.backtrace) if exception.present?

      ActiveSupport::Notifications.instrument "#{type}_failed_repeatedly.datacycle", {
        exception: error,
        namespace: "repeated_failure_#{type}",
        mailing_list: options.dig('error_notification', 'emails'),
        type:,
        external_system: self
      }
    end

    def refresh(options = {})
      raise "Missing refresh_strategy for #{name}, options given: #{options}" if export_refresh_strategy.nil?

      utility_object = DataCycleCore::Export::PushObject.new(
        external_system: self,
        action: :refresh
      )
      export_refresh_strategy.process(utility_object:, options:)
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
    ensure
      Mongoid.override_database(nil)
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

    # the content is the primary source of this system, so the templates are read from the
    # import options (ExternalSystemSync reads them for its own sync_type)
    def external_url(content)
      return if content&.external_key.blank?

      format_url_template(default_options&.dig('external_url'), locale: I18n.locale, external_key: content.external_key)
    end

    def external_detail_url(content)
      return if content&.external_key.blank?

      format_url_template(default_options&.dig('external_detail_url'), locale: I18n.locale, external_key: content.external_key)
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

    def endpoint_module
      return if module_base.blank?

      MasterData::ImportExternalSystems.full_module_path(module_base, 'Endpoint')&.safe_constantize
    end

    def reload(options = nil)
      reset_memoized_variables!

      super
    end

    def reset_memoized_variables!
      remove_instance_variable(:@export_config) if instance_variable_defined?(:@export_config)
      remove_instance_variable(:@export_transformations) if instance_variable_defined?(:@export_transformations)
      remove_instance_variable(:@export_refresh_strategy) if instance_variable_defined?(:@export_refresh_strategy)
      remove_instance_variable(:@refresh_config) if instance_variable_defined?(:@refresh_config)
      remove_instance_variable(:@download_config) if instance_variable_defined?(:@download_config)
      remove_instance_variable(:@import_config) if instance_variable_defined?(:@import_config)
      remove_instance_variable(:@transformations) if instance_variable_defined?(:@transformations)
      remove_instance_variable(:@download_list) if instance_variable_defined?(:@download_list)
      remove_instance_variable(:@download_list_ranked) if instance_variable_defined?(:@download_list_ranked)
      remove_instance_variable(:@download_pretty_list) if instance_variable_defined?(:@download_pretty_list)
      remove_instance_variable(:@import_list) if instance_variable_defined?(:@import_list)
      remove_instance_variable(:@import_list_ranked) if instance_variable_defined?(:@import_list_ranked)
      remove_instance_variable(:@import_pretty_list) if instance_variable_defined?(:@import_pretty_list)
      remove_instance_variable(:@credentials) if instance_variable_defined?(:@credentials)
      remove_instance_variable(:@default_options) if instance_variable_defined?(:@default_options)
    end

    def step_info_for(key)
      last_import_step_time_info[key.to_s] || {}
    end

    def locales
      default_options&.dig('locales')
    end

    private

    def set_identifier
      self.identifier ||= name.to_s.to_slug
    end

    def download_accessors
      return @download_accessors if defined? @download_accessors

      @download_accessors = full_sorted_steps(:download)
        .map { |name| timestamp_key_for_step(name, :download).to_sym }
    end

    def import_accessors
      return @import_accessors if defined? @import_accessors

      @import_accessors = full_sorted_steps(:import)
        .map { |name| timestamp_key_for_step(name, :import).to_sym }
    end
  end
end
