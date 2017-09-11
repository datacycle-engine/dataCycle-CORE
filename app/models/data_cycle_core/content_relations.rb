module DataCycleCore
  module ContentRelations
    extend ActiveSupport::Concern

    module ClassMethods
      def content_relations(options={}, &block)
        table_given = options[:table_name]
        postfix = options[:postfix]

        table_full = table_given.to_s.singularize
        table_full += "_#{postfix}" unless postfix.nil?

        classification_relation_table = ['classification', table_given.to_s.singularize].sort.join('_')
        classification_relation_table += "_#{postfix}" unless postfix.nil?
        classification_relation_table = classification_relation_table.pluralize.to_sym

        # relation content to classification
        has_many classification_relation_table, foreign_key: table_full.foreign_key, dependent: :destroy
        has_many :classifications, through: classification_relation_table
        has_many :classification_groups, through: :classifications
        has_many :classification_aliases, through: :classification_groups
        has_many :display_classification_aliases, -> { where("classification_aliases.internal = ?", false) }, through: :classification_groups, source: :classification_alias

        # relation content to all other contents
        (DataCycleCore.content_tables - [table_given]).map(&:singularize).each do |content_name|
          content_relation_table = [content_name, table_given.to_s.singularize].sort.join('_')
          if postfix.nil?
            content_relation_table_name = content_relation_table.pluralize.to_sym
            has_many content_relation_table_name, dependent: :destroy
            has_many content_name.pluralize.to_sym, through: content_relation_table_name
          elsif
            content_relation_table_name = (content_relation_table +"_#{postfix}").pluralize.to_sym
            target_name = content_name+"_#{postfix}"
            #puts "#{content_relation_table_name} | #{"DataCycleCore::"+(content_relation_table.to_s.classify)+"::History"} | #{table_given.singularize+"_history_id"}"
            has_many content_relation_table_name, class_name: "DataCycleCore::"+(content_relation_table.to_s.classify)+"::History", dependent: :destroy, foreign_key: table_given.singularize+"_history_id"
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
