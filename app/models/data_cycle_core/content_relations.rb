module DataCycleCore
  module ContentRelations
    extend ActiveSupport::Concern

    module ClassMethods
      def content_relations(options={}, &block)
        table_given = options[:table_name]

        # relation content to classification
        has_many ['classification', table_given.to_s.singularize].sort.join('_').pluralize.to_sym, dependent: :destroy
        has_many :classifications, through: ['classification', table_given.to_s.singularize].sort.join('_').pluralize.to_sym
        has_many :classification_groups, through: :classifications
        has_many :classification_aliases, through: :classification_groups
        has_many :display_classification_aliases, -> { where("classification_aliases.internal = ?", false) }, through: :classification_groups, source: :classification_alias

        # relation content to all other contents
        (DataCycleCore.content_tables - [table_given]).map(&:singularize).each do |content_name|
          has_many [content_name, table_given.to_s.singularize].sort.join('_').pluralize.to_sym, dependent: :destroy
          has_many content_name.pluralize.to_sym, through: [content_name, table_given.to_s.singularize].sort.join('_').pluralize.to_sym
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
