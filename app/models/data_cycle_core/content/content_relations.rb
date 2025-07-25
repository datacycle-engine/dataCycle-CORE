# frozen_string_literal: true

module DataCycleCore
  module Content
    module ContentRelations
      extend ActiveSupport::Concern

      CONTENT_TYPES = [
        CONTENT_TYPE_ENTITY = 'entity',
        CONTENT_TYPE_EMBEDDED = 'embedded'
      ].freeze

      included do
        extend DataCycleCore::Common::RelationClassMethods

        belongs_to :parent, class_name: name, foreign_key: 'is_part_of', inverse_of: :children, touch: false
        has_many :children, class_name: name, foreign_key: 'is_part_of', inverse_of: :parent, dependent: :destroy

        case name
        when 'DataCycleCore::Thing'
          has_many :classification_contents, class_name: 'DataCycleCore::ClassificationContent', foreign_key: 'content_data_id', dependent: :delete_all
          has_many :classifications, through: :classification_contents
        when 'DataCycleCore::Thing::History'
          has_many :classification_content_histories, class_name: 'DataCycleCore::ClassificationContent::History', foreign_key: 'content_data_history_id', dependent: :delete_all
          has_many :classifications, through: :classification_content_histories
        end

        has_many :classification_groups, through: :classifications
        has_many :classification_aliases, -> { distinct }, through: :classification_groups
        has_many :primary_classification_aliases, through: :classifications, source: :primary_classification_alias
        has_many :classification_alias_paths_transitive, through: :primary_classification_aliases

        # relation content to all other contents
        has_many :content_content_b, -> { order(order_a: :asc, content_a_id: :asc) }, class_name: 'DataCycleCore::ContentContent', foreign_key: 'content_b_id', dependent: :delete_all, inverse_of: :content_b
        has_many :content_a, through: :content_content_b
        has_many :content_content_b_history, class_name: 'DataCycleCore::ContentContent::History', as: :content_b_history, dependent: :delete_all
        has_many :content_content_a, -> { order(order_a: :asc, content_b_id: :asc) }, class_name: 'DataCycleCore::ContentContent', foreign_key: 'content_a_id', dependent: :delete_all, inverse_of: :content_a
        has_many :content_b, through: :content_content_a
        has_many :content_b_linked, -> { where.not(content_type: CONTENT_TYPE_EMBEDDED) }, through: :content_content_a, source: :content_b
        has_many :content_b_embedded, -> { where(content_type: CONTENT_TYPE_EMBEDDED) }, through: :content_content_a, source: :content_b
        has_many :content_content_a_history, class_name: 'DataCycleCore::ContentContent::History', foreign_key: 'content_a_history_id', dependent: :delete_all, inverse_of: :content_a_history

        belongs_to :external_source, class_name: 'DataCycleCore::ExternalSystem'
        belongs_to :created_by_user, foreign_key: :created_by, class_name: 'DataCycleCore::User'
        belongs_to :updated_by_user, foreign_key: :updated_by, class_name: 'DataCycleCore::User'
        belongs_to :deleted_by_user, foreign_key: :deleted_by, class_name: 'DataCycleCore::User'
        belongs_to :representation_of, class_name: 'DataCycleCore::User'

        has_many :watch_list_data_hashes, inverse_of: :thing, dependent: :destroy
        has_many :watch_lists, through: :watch_list_data_hashes

        has_many :subscriptions, as: :subscribable, dependent: :delete_all
        has_many :data_link_content_items, as: :content
        has_many :indirect_data_links, through: :data_link_content_items
        has_many :data_links, as: :item, dependent: :delete_all
        has_many :valid_write_links, -> { valid.writable }, class_name: 'DataCycleCore::DataLink', as: :item
        has_many :asset_contents, dependent: :destroy, foreign_key: :thing_id
        has_many :assets, through: :asset_contents

        belongs_to :thing_template, inverse_of: :things, foreign_key: :template_name, primary_key: :template_name
        delegate :schema, :api_schema_types, to: :thing_template
      end

      module ClassMethods
        def data_links
          return DataCycleCore::DataLink.none if self == DataCycleCore::Thing::History

          DataCycleCore::DataLink.where(item_id: all.select(:id))
        end

        def thing_templates(preload: false)
          load_relation(relation_name: :thing_template, preload:)
        end

        def content_content_a(preload: false)
          load_relation(relation_name: __method__, preload:)
        end

        def classification_contents(preload: false)
          return DataCycleCore::ClassificationContent.none if self == DataCycleCore::Thing::History

          load_relation(relation_name: :classification_contents, preload:)
        end

        def collected_classification_contents(preload: false)
          return DataCycleCore::CollectedClassificationContent.none if self == DataCycleCore::Thing::History

          load_relation(relation_name: :collected_classification_contents, preload:)
        end

        def asset_contents(preload: false)
          return DataCycleCore::AssetContent.none if self == DataCycleCore::Thing::History

          load_relation(relation_name: :asset_contents, preload:)
        end

        def schedules(preload: false)
          return DataCycleCore::Schedule.none if self == DataCycleCore::Thing::History

          load_relation(relation_name: :schedules, preload:)
        end

        def timeseries(preload: false)
          return DataCycleCore::Timeseries.none if self == DataCycleCore::Thing::History

          load_relation(relation_name: :timeseries, preload:)
        end
      end

      def valid_writable_links_by_receiver?(user)
        data_links = DataCycleCore::DataLink.valid.writable.by_receiver(user)

        sub_queries = []
        sub_queries << data_links.thing_links.where(item_id: id).select(:id).reorder(nil).to_sql
        sub_queries << data_links.joins(watch_list: :watch_list_data_hashes).where(watch_list_data_hashes: { thing_id: id }).select(:id).reorder(nil).to_sql

        DataLink.where("#{DataLink.table_name}.id IN (#{DataLink.send(:sanitize_sql_array, [sub_queries.join(' UNION ')])})").exists?
      end

      def display_classification_aliases(context)
        if classification_aliases.loaded?
          ca_query = classification_aliases
          ca_query = ca_query.includes(:classification_tree_label) unless classification_aliases.first&.association(:classification_tree_label)&.loaded?
          ca_query = ca_query.includes(:classification_alias_path) unless classification_aliases.first&.association(:classification_alias_path)&.loaded?
          ca_query.to_a.select { |ca| Array.wrap(ca.classification_tree_label&.visibility).intersect?(Array.wrap(context)) }
        else
          classification_aliases.includes(:classification_alias_path).in_context(context)
        end
      end

      def assigned_classification_aliases
        primary_classification_aliases
      end

      def mapped_classification_aliases
        if DataCycleCore::Feature::TransitiveClassificationPath.enabled?
          classification_alias_paths_transitive.mapped_classification_aliases
        else
          classification_aliases.where.not(id: primary_classification_aliases.pluck(:id))
        end
      end

      def classification_alias_for_tree(tree_name)
        if classification_aliases.loaded?
          ca_query = classification_aliases
          ca_query = ca_query.includes(:classification_tree_label) unless classification_aliases.first&.association(:classification_tree_label)&.loaded?
          ca_query.to_a.detect { |ca| ca.classification_tree_label&.name == tree_name }
        else
          classification_aliases.includes(:classification_tree_label).find_by(classification_tree_labels: { name: tree_name })
        end
      end

      def classification_aliases_for_tree(tree_name:)
        classification_aliases.joins(:classification_tree_label).where(classification_tree_labels: { name: tree_name })
      end

      def classifications_for_tree(tree_name:)
        classification_aliases_for_tree(tree_name:).primary_classifications
      end

      def is_related? # rubocop:disable Naming/PredicatePrefix
        content_content_b.except(:order).exists?
      end

      def has_related? # rubocop:disable Naming/PredicatePrefix
        content_content_a.except(:order).exists?
      end

      def has_cached_related_contents? # rubocop:disable Naming/PredicatePrefix
        cached_related_contents.exists?
      end

      def related_contents(embedded: false)
        tree_query = <<-SQL.squish
          WITH RECURSIVE content_tree(id) AS (
              SELECT #{content_a_id_column}
              FROM #{content_content_table}
              WHERE #{content_b_id_column} = :id
            UNION ALL
              SELECT #{content_a_id_column}
              FROM #{content_content_table}
              INNER JOIN #{self.class.table_name} ON #{self.class.table_name}.id = #{content_b_id_column}
              INNER JOIN content_tree ON content_tree.id = #{content_b_id_column}
              WHERE #{self.class.table_name}.content_type = :content_type_embedded
          )
          SELECT DISTINCT id FROM content_tree
        SQL

        sanitized_base = ActiveRecord::Base.send(
          :sanitize_sql_array, [
            tree_query,
            {id:, content_type_embedded: CONTENT_TYPE_EMBEDDED}
          ]
        )
        query = self.class.where("#{self.class.table_name}.id IN (#{sanitized_base})")
        query = query.where.not(content_type: CONTENT_TYPE_EMBEDDED) unless embedded
        query
      end

      def depending_contents
        raw_sql = <<-SQL.squish
          WITH RECURSIVE content_dependencies AS (
            SELECT content_content_links.content_a_id AS id
            FROM content_content_links
            WHERE content_content_links.content_b_id = :id::UUID
            AND content_content_links.relation IS NOT NULL
            UNION
            SELECT content_content_links.content_a_id AS id
            FROM content_content_links
              JOIN content_dependencies ON content_dependencies.id = content_content_links.content_b_id
            WHERE content_content_links.relation IS NOT NULL
          )
          SELECT things.id
          FROM things
          WHERE things.id != :id::UUID
          AND EXISTS (
              SELECT 1
              FROM content_dependencies
              WHERE content_dependencies.id = #{self.class.table_name}.#{self.class.primary_key}
            )
        SQL

        self.class
          .where.not(content_type: 'embedded')
          .where("things.id IN (#{ActiveRecord::Base.send(:sanitize_sql_array, [raw_sql, {id:}])})")
      end

      def linked_contents
        # does not work for Histories, due to thing ids (instead of thing_history ids) in content_content_histories

        tree_query = <<-SQL.squish
          WITH RECURSIVE content_tree(id) AS (
            SELECT #{self.class.table_name}.id as id, array[#{self.class.table_name}.id] as all_things
            FROM #{self.class.table_name}
            INNER JOIN #{content_content_table} ON #{self.class.table_name}.id = #{content_b_id_column}
            WHERE #{content_a_id_column} = :id
            AND #{self.class.table_name}.content_type != :content_type_embedded
          UNION ALL
            SELECT #{self.class.table_name}.id as id, content_tree.all_things||#{self.class.table_name}.id
            FROM #{self.class.table_name}
            INNER JOIN #{content_content_table} ON #{self.class.table_name}.id = #{content_b_id_column}
            INNER JOIN content_tree ON content_tree.id = #{content_a_id_column}
            AND #{self.class.table_name}.id <> ALL (content_tree.all_things)
          )
          SELECT DISTINCT id FROM content_tree
        SQL

        self.class.where("#{self.class.table_name}.id IN (#{ActiveRecord::Base.send(
          :sanitize_sql_array, [
            tree_query,
            {id:,
             content_type_embedded: CONTENT_TYPE_EMBEDDED}
          ]
        )})")
      end

      def embedded_contents
        tree_query = <<-SQL.squish
          WITH RECURSIVE content_tree(id) AS (
            SELECT #{self.class.table_name}.id as id, array[#{self.class.table_name}.id] as all_things
            FROM #{self.class.table_name}
            INNER JOIN #{content_content_table} ON #{self.class.table_name}.id = #{content_b_id_column}
            WHERE #{content_a_id_column} = :id
            AND #{self.class.table_name}.content_type = :content_type_embedded
          UNION ALL
            SELECT #{self.class.table_name}.id as id, content_tree.all_things||#{self.class.table_name}.id
            FROM #{self.class.table_name}
            INNER JOIN #{content_content_table} ON #{self.class.table_name}.id = #{content_b_id_column}
            INNER JOIN content_tree ON content_tree.id = #{content_a_id_column}
            AND #{self.class.table_name}.id <> ALL (content_tree.all_things)
            AND #{self.class.table_name}.content_type = :content_type_embedded
          )
          SELECT DISTINCT id FROM content_tree
        SQL

        self.class.where("#{self.class.table_name}.id IN (#{ActiveRecord::Base.send(
          :sanitize_sql_array, [
            tree_query,
            {id:,
             content_type_embedded: CONTENT_TYPE_EMBEDDED}
          ]
        )})")
      end

      def cached_related_contents
        return self.class.none if history?

        tree_query = <<-SQL.squish
          WITH RECURSIVE paths (content_b_id, content_a_id, PATH) AS (
            SELECT DISTINCT ON (c.content_a_id) c.content_b_id, c.content_a_id, ARRAY[c.content_b_id, c.content_a_id]
            FROM content_content_links c
            WHERE c.content_b_id = :id
            AND c.relation IS NOT NULL
            UNION ALL
            SELECT DISTINCT ON (d.content_a_id) d.content_b_id, d.content_a_id, p.path || ARRAY[d.content_a_id]
            FROM paths p
            INNER JOIN content_content_links d ON p.content_a_id = d.content_b_id
            WHERE d.content_a_id != ALL (p.path)
            AND d.relation IS NOT NULL
            AND ARRAY_LENGTH(p.path, 1) <= :depth
          )
          SELECT DISTINCT paths.content_a_id FROM paths
        SQL

        self.class.where("#{self.class.table_name}.id IN (#{ActiveRecord::Base.send(
          :sanitize_sql_array, [tree_query, {id:, depth: DataCycleCore.cache_invalidation_depth}]
        )})")
      end

      def template_name=(value)
        super

        return if new_record? || !template_name_changed?

        validate_template!
        update_template_properties
      end

      def thing_template=(value)
        super

        return if new_record? || !thing_template_changed?

        validate_template!
        self.template_name = thing_template.template_name
        update_template_properties
      end

      private

      def content_content_table
        history? ? 'content_content_histories' : 'content_contents'
      end

      def content_a_id_column
        "#{content_content_table}.#{history? ? 'content_a_history_id' : 'content_a_id'}"
      end

      def content_b_id_column
        "#{content_content_table}.#{history? ? 'content_b_history_id' : 'content_b_id'}"
      end

      def relation_a_column
        "#{content_content_table}.relation_a"
      end

      def relation_b_column
        "#{content_content_table}.relation_b"
      end
    end
  end
end
