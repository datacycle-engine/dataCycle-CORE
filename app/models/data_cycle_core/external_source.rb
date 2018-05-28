module DataCycleCore
  class ExternalSource < ApplicationRecord
    has_many :use_cases
    has_many :classifications
    has_many :classification_alias
    has_many :classification_contents
    has_many :classification_content_histories
    has_many :classification_groups
    has_many :classification_tree_labels
    has_many :classification_trees
    has_many :content_contents
    has_many :content_content_histories

    DataCycleCore.content_tables.each do |item_table|
      has_many item_table.to_sym
      has_many "#{item_table.singularize}_histories".to_sym, class_name: "DataCycleCore::#{item_table.classify}::History", inverse_of: :external_sources
    end

    def download(options = {}, &block)
      raise ArgumentError, 'expected a valid download config' if config.dig('download').nil?
      full_options = options.with_indifferent_access.merge({ download: download_config.symbolize_keys })
      elementary_downloader(full_options, &block)
    end

    def download_single(name, options = {}, &block)
      raise ArgumentError, 'expected name to have a valid download config' if download_config&.with_indifferent_access&.dig(name).nil?
      full_options = options.symbolize_keys.merge({ download: { name => download_config.dig(name).symbolize_keys } })
      elementary_downloader(full_options, &block)
    end

    def elementary_downloader(options, &block)
      config['download'].constantize.new(id).download(options, &block)
    end

    def download_config
      config&.dig('download_config')&.symbolize_keys
    end

    def download_list
      download_config&.symbolize_keys&.keys
    end

    def import(options = {}, &block)
      raise ArgumentError, 'expected a valid import config' if config&.with_indifferent_access&.dig('import').nil?
      full_options = options.symbolize_keys.merge({ import: import_config.symbolize_keys })
      elementary_importer(full_options, &block)
    end

    def import_single(name, options = {}, &block)
      raise ArgumentError, 'expected name to have a valid import config' if import_config&.with_indifferent_access&.dig(name).nil?
      full_options = options.symbolize_keys.merge({ import: { name => import_config.dig(name).symbolize_keys } })
      elementary_importer(full_options, &block)
      nil
    end

    def elementary_importer(options, &block)
      config['import'].constantize.new(id).import(options, &block)
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
