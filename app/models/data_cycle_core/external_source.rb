# frozen_string_literal: true

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
      download_config.sort { |d1, d2|
        d1.second['sorting'] <=> d2.second['sorting']
      }.each do |(name, _)|
        download_single(name, options, &block)
      end
    end

    def download_single(name, options = {}, &block)
      full_options = (default_options || {}).symbolize_keys.merge({ download: download_config.dig(name).symbolize_keys.except(:sorting) }).merge(options.symbolize_keys)
      DataCycleCore::Generic::Download.new(id).download(full_options, &block)
    end

    def download_config
      config&.dig('download_config')&.symbolize_keys
    end

    def download_list
      download_config&.symbolize_keys&.keys
    end

    def import(options = {}, &block)
      import_config.sort { |d1, d2|
        d1.second['sorting'] <=> d2.second['sorting']
      }.each do |(name, _)|
        import_single(name, options, &block)
      end
    end

    def import_single(name, options = {}, &block)
      full_options = (default_options || {}).symbolize_keys.merge({ import: import_config.dig(name).symbolize_keys.except(:sorting) }).merge(options.symbolize_keys)
      DataCycleCore::Generic::Import.new(id).import(full_options, &block)
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
