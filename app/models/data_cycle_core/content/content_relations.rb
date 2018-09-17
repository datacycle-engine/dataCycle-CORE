# frozen_string_literal: true

module DataCycleCore
  module Content
    module ContentRelations
      extend ActiveSupport::Concern

      module ClassMethods
        def content_relations(options = {}, &block)
          table_given = options[:table_name]
          postfix = options[:postfix]

          classification_content_table = 'classification_content'
          classification_content_table += "_#{postfix}" unless postfix.nil?
          class_name = 'DataCycleCore::ClassificationContent'
          class_name += "::#{postfix.capitalize}" unless postfix.nil?
          content_name = 'content_data'
          content_name += "_#{postfix}" unless postfix.nil?

          # relation content to classification
          has_many classification_content_table.to_sym, class_name: class_name, foreign_key: content_name.foreign_key, dependent: :destroy
          has_many :classifications, through: classification_content_table.to_sym
          has_many :classification_groups, through: :classifications
          has_many :classification_aliases, through: :classification_groups
          has_many :display_classification_aliases, -> { where('classification_aliases.internal = ?', false) }, through: :classification_groups, source: :classification_alias

          # relation content to search
          has_many :content_search_all, class_name: 'DataCycleCore::Search', foreign_key: content_name.foreign_key, dependent: :destroy if postfix.nil?

          # relation content to all other contents
          has_many :content_content_a, class_name: 'DataCycleCore::ContentContent', as: :content_a, dependent: :destroy
          has_many :content_content_b, class_name: 'DataCycleCore::ContentContent', as: :content_b, dependent: :destroy
          has_many :content_content_a_history, class_name: 'DataCycleCore::ContentContent::History', as: :content_a_history, dependent: :destroy
          has_many :content_content_b_history, class_name: 'DataCycleCore::ContentContent::History', as: :content_b_history, dependent: :destroy

          (DataCycleCore.content_tables + DataCycleCore.linked_tables).map(&:singularize).each do |content_table_name|
            if postfix.nil?
              if table_given.to_s.singularize <= content_table_name
                has_many content_table_name.pluralize.to_sym, through: :content_content_a, source: :content_b, source_type: "DataCycleCore::#{content_table_name.classify}"
              else
                has_many content_table_name.pluralize.to_sym, through: :content_content_b, source: :content_a, source_type: "DataCycleCore::#{content_table_name.classify}"
              end
            elsif table_given.to_s.singularize <= content_table_name
              has_many "#{content_table_name}_#{postfix}".pluralize.to_sym, through: :content_content_a_history, source: :content_b_history, source_type: "DataCycleCore::#{content_table_name.classify}::#{postfix.capitalize}"
            else
              has_many "#{content_table_name}_#{postfix}".pluralize.to_sym, through: :content_content_b_history, source: :content_a_history, source_type: "DataCycleCore::#{content_table_name.classify}::#{postfix.capitalize}"
            end
          end

          belongs_to :external_source

          has_many :watch_list_data_hashes, as: :hashable, dependent: :destroy
          has_many :watch_lists, through: :watch_list_data_hashes

          has_many :subscriptions, as: :subscribable, dependent: :destroy
          has_many :data_link_content_items, as: :content
          has_many :indirect_data_links, through: :data_link_content_items
          has_many :data_links, as: :item, dependent: :destroy
        end
      end
    end
  end
end
