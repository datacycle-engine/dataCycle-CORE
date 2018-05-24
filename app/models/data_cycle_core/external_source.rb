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
      full_options = options.merge({ download: config['download_config'].symbolize_keys })
      if config['download'].starts_with?('::') || config['download'].starts_with?('DataCycleCore::')
        config['download'].constantize.new(id).download(full_options, &block)
      else
        "DataCycleCore::#{config['download']}".constantize.new(id).download(full_options, &block)
      end
    end

    def import(options = {}, &bock)
      full_options = options.merge({ import: config['import_config'].symbolize_keys })
      if config['import'].starts_with?('::') || config['import'].starts_with?('DataCycleCore::')
        config['import'].constantize.new(id).import(full_options, &bock)
      else
        "DataCycleCore::#{config['import']}".constantize.new(id).import(full_options, &bock)
      end
    end
  end
end
