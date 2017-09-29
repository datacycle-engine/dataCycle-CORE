module DataCycleCore
  module ContentRelations
    extend ActiveSupport::Concern

    module ClassMethods
      def content_relations(options={}, &block)
        table_given = options[:table_name]
        postfix = options[:postfix]

        table_full = table_given.to_s.singularize
        table_full += "_#{postfix}" unless postfix.nil?

        classification_content_table = 'classification_content'
        classification_content_table += "_#{postfix}" unless postfix.nil?
        class_name = "DataCycleCore::ClassificationContent"
        class_name += "::#{postfix.capitalize}" unless postfix.nil?
        content_name = 'content_data'
        content_name += "_#{postfix}" unless postfix.nil?

        # relation content to classification
        has_many classification_content_table.to_sym, class_name: class_name, as: content_name.to_sym, foreign_key: content_name.foreign_key
        has_many :classifications, through: classification_content_table.to_sym
        has_many :classification_groups, through: :classifications
        has_many :classification_aliases, through: :classification_groups
        has_many :display_classification_aliases, -> { where("classification_aliases.internal = ?", false) }, through: :classification_groups, source: :classification_alias

        # relation content to search
        if postfix.nil?
          has_one :content_search, class_name: 'DataCycleCore::Search', foreign_key: content_name.foreign_key
        end

        # relation content to all other contents
        (DataCycleCore.content_tables - [table_given]).map(&:singularize).each do |content_name|
          content_relation_table = [content_name, table_given.to_s.singularize].sort.join('_')
          if postfix.nil?
            content_relation_table_name = content_relation_table.pluralize.to_sym
            has_many content_relation_table_name, dependent: :destroy
            has_many content_name.pluralize.to_sym, through: content_relation_table_name
          elsif
            content_relation_table_name = (content_relation_table + "_#{postfix}").pluralize.to_sym
            target_name = content_name + "_#{postfix}"
            has_many content_relation_table_name, class_name: "DataCycleCore::" + (content_relation_table.to_s.classify) + "::#{postfix.capitalize}", dependent: :destroy, foreign_key: table_given.singularize + "_#{postfix}_id"
            has_many target_name.pluralize.to_sym, through: content_relation_table_name
          end
        end

        belongs_to :external_source

        has_many :watch_list_data_hashes, as: :hashable, dependent: :destroy
        has_many :watch_lists, through: :watch_list_data_hashes

        has_one :show_link, -> { DataLink.show_links }, class_name: "DataLink", as: :item
        has_one :edit_link, -> { DataLink.edit_links }, class_name: "DataLink", as: :item
      end
    end
  end
end
