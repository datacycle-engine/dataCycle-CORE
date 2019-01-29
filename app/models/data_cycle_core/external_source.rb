# frozen_string_literal: true

module DataCycleCore
  class ExternalSource < ApplicationRecord
    has_many :classifications
    has_many :classification_alias
    has_many :classification_contents
    has_many :classification_content_histories
    has_many :classification_groups
    has_many :classification_tree_labels
    has_many :classification_trees
    has_many :content_contents
    has_many :content_content_histories
    has_many :things
    has_many :thing_histories, class_name: 'DataCycleCore::Thing::History', inverse_of: :external_source

    def download(options = {}, &block)
      ts_start = Time.zone.now
      download_config.sort { |d1, d2|
        d1.second['sorting'] <=> d2.second['sorting']
      }.each do |(name, _)|
        download_single(name, options, &block)
      end
      self.last_download = ts_start
      save
    end

    def download_single(name, options = {})
      raise "unknown downloader name: #{name}" if download_config.dig(name).blank?
      full_options = (default_options || {}).deep_symbolize_keys.deep_merge({ download: download_config.dig(name).deep_symbolize_keys.except(:sorting) }).deep_merge(options.deep_symbolize_keys)
      locales = full_options.dig(:download, :locales) || full_options.dig(:locales) || I18n.available_locales
      utility_object = DataCycleCore::Generic::DownloadObject.new(full_options.merge(external_source: self, locales: locales))
      raise "Missing download_strategy for #{name}, options given: #{options}" if full_options.dig(:download, :download_strategy).blank?
      full_options.dig(:download, :download_strategy).constantize.download_content(utility_object: utility_object, options: full_options.merge(locales: locales).deep_symbolize_keys)
    end
    alias single_download download_single

    def download_config
      config&.dig('download_config')&.symbolize_keys
    end

    def download_list
      download_config&.symbolize_keys&.keys
    end

    def import(options = {}, &block)
      ts_start = Time.zone.now
      import_config.sort { |d1, d2|
        d1.second['sorting'] <=> d2.second['sorting']
      }.each do |(name, _)|
        import_single(name, options, &block)
      end
      self.last_import = ts_start
      save
    end

    def import_single(name, options = {})
      raise "unknown importer name: #{name}" if import_config.dig(name).blank?
      full_options = (default_options || {}).deep_symbolize_keys.deep_merge({ import: import_config.dig(name).deep_symbolize_keys.except(:sorting) }).deep_merge(options.deep_symbolize_keys)
      locales = full_options[:import][:locales] || full_options[:locales] || I18n.available_locales
      utility_object = DataCycleCore::Generic::ImportObject.new(full_options.merge(external_source: self, locales: locales))
      raise "Missing import_strategy for #{name}, options given: #{options}" if full_options.dig(:import, :import_strategy).blank?
      full_options.dig(:import, :import_strategy).constantize.import_data(utility_object: utility_object, options: full_options.merge(locales: locales).deep_symbolize_keys)
    end
    alias single_import import_single

    def import_one(name, external_key, options = {})
      raise 'no external key given' if external_key.blank?
      import_single(name, options.deep_merge({ mode: 'full', import: { source_filter: { external_id: external_key } } }))
    end

    def import_config
      config&.dig('import_config')&.symbolize_keys
    end

    def import_list
      import_config&.symbolize_keys&.keys
    end

    def collections
      mongo_database = "#{Generic::Collection.database_name}_#{id}"
      Mongoid.override_database(mongo_database)
      Mongoid.clients[id] = {
        'database' => mongo_database,
        'hosts' => Mongoid.default_client.cluster.servers.map(&:address).map { |adr| "#{adr.host}:#{adr.port}" },
        'options' => nil
      }
      OpenStruct.new(Hash[Mongoid.client(id).collections.map { |item| [item.name, item] }])
    end
  end
end
