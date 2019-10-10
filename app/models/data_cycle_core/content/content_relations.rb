# frozen_string_literal: true

module DataCycleCore
  module Content
    module ContentRelations
      extend ActiveSupport::Concern

      module ClassMethods
        def content_relations(options = {})
          table_given = options[:table_name]
          postfix = options[:postfix]

          self_class = "DataCycleCore::#{table_given.classify}"
          self_class += "::#{postfix.capitalize}" unless postfix.nil?

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
          has_many :primary_classification_groups, through: :classifications
          has_many :primary_classification_aliases, through: :primary_classification_groups, source: :classification_alias

          # relation content to all other contents
          has_many :content_content_b, -> { order(order_a: :asc) }, class_name: 'DataCycleCore::ContentContent', foreign_key: 'content_b_id', dependent: :destroy, inverse_of: :content_b
          has_many :content_a, through: :content_content_b
          has_many :content_content_b_history, class_name: 'DataCycleCore::ContentContent::History', as: :content_b_history, dependent: :destroy
          has_many :content_content_a, -> { order(order_a: :asc) }, class_name: 'DataCycleCore::ContentContent', foreign_key: 'content_a_id', dependent: :destroy, inverse_of: :content_a
          has_many :content_b, through: :content_content_a
          has_many :content_b_linked, -> { where.not(content_type: 'embedded') }, through: :content_content_a, source: :content_b
          has_many :content_b_embedded, -> { where(content_type: 'embedded') }, through: :content_content_a, source: :content_b
          has_many :content_content_a_history, class_name: 'DataCycleCore::ContentContent::History', foreign_key: 'content_a_history_id', dependent: :destroy, inverse_of: :content_a_history

          belongs_to :external_source
          belongs_to :created_by_user, foreign_key: :created_by, class_name: 'DataCycleCore::User'
          belongs_to :updated_by_user, foreign_key: :updated_by, class_name: 'DataCycleCore::User'
          belongs_to :deleted_by_user, foreign_key: :deleted_by, class_name: 'DataCycleCore::User'
          belongs_to :representation_of, foreign_key: :representation_of_id, class_name: 'DataCycleCore::User'

          belongs_to :parent, class_name: self_class, foreign_key: 'is_part_of', inverse_of: :children, touch: false
          has_many :children, class_name: self_class, foreign_key: 'is_part_of', inverse_of: :parent, dependent: :destroy

          has_many :watch_list_data_hashes, as: :hashable, dependent: :destroy
          has_many :watch_lists, through: :watch_list_data_hashes

          has_many :subscriptions, as: :subscribable, dependent: :destroy
          has_many :data_link_content_items, as: :content
          has_many :indirect_data_links, through: :data_link_content_items
          has_many :data_links, as: :item, dependent: :destroy

          has_many :asset_contents, dependent: :destroy, as: :content_data
          has_many :assets, through: :asset_contents
        end
      end

      def display_classification_aliases(context)
        ca_query = classification_aliases
        ca_query = ca_query.includes(:classification_tree_label) unless classification_aliases.first&.association(:classification_tree_label)&.loaded?
        ca_query = ca_query.includes(:classification_alias_path) unless classification_aliases.first&.association(:classification_alias_path)&.loaded?
        ca_query.to_a.uniq.select { |ca| (Array(ca.classification_tree_label&.visibility) & Array(context)).size.positive? }
      end

      def assigned_classification_aliases
        primary_classification_aliases
      end

      def mapped_classification_aliases
        classification_aliases.where.not(id: primary_classification_aliases.pluck(:id))
      end

      def is_related?
        content_content_b.exists?
      end

      def has_related?
        content_content_a.exists?
      end

      def related_contents
        tree_query = <<-SQL
          WITH RECURSIVE content_tree(id) AS (
              SELECT things.id
              FROM things
              INNER JOIN content_contents ON things.id = content_contents.content_a_id
              WHERE content_contents.content_b_id = '#{id}'
            UNION ALL
              SELECT things.id
              FROM things
              INNER JOIN content_contents ON things.id = content_contents.content_a_id
              INNER JOIN content_tree ON content_tree.id = content_contents.content_b_id
              WHERE things.content_type = 'embedded'
          )
          SELECT DISTINCT id FROM content_tree
        SQL

        self.class.where("things.id IN (#{tree_query})")
      end
    end
  end
end
