# frozen_string_literal: true

module DataCycleCore
  module Content
    module ContentRelations
      extend ActiveSupport::Concern

      CONTENT_TYPES = [
        CONTENT_TYPE_ENTITY = 'entity',
        CONTENT_TYPE_EMBEDDED = 'embedded'
      ].freeze

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
          has_many classification_content_table.to_sym, class_name:, foreign_key: content_name.foreign_key, dependent: :destroy
          has_many :classifications, through: classification_content_table.to_sym
          has_many :classification_groups, through: :classifications
          has_many :classification_aliases, -> { distinct }, through: :classification_groups
          has_many :primary_classification_groups, through: :classifications
          has_many :primary_classification_aliases, through: :primary_classification_groups, source: :classification_alias
          has_many :classification_alias_paths_transitive, through: :primary_classification_aliases

          # relation content to all other contents
          has_many :content_content_b, -> { order(order_a: :asc, content_a_id: :asc) }, class_name: 'DataCycleCore::ContentContent', foreign_key: 'content_b_id', dependent: :destroy, inverse_of: :content_b
          has_many :content_a, through: :content_content_b
          has_many :content_content_b_history, class_name: 'DataCycleCore::ContentContent::History', as: :content_b_history, dependent: :destroy
          has_many :content_content_a, -> { order(order_a: :asc, content_b_id: :asc) }, class_name: 'DataCycleCore::ContentContent', foreign_key: 'content_a_id', dependent: :destroy, inverse_of: :content_a
          has_many :content_b, through: :content_content_a
          has_many :content_b_linked, -> { where.not(content_type: CONTENT_TYPE_EMBEDDED) }, through: :content_content_a, source: :content_b
          has_many :content_b_embedded, -> { where(content_type: CONTENT_TYPE_EMBEDDED) }, through: :content_content_a, source: :content_b
          has_many :content_content_a_history, class_name: 'DataCycleCore::ContentContent::History', foreign_key: 'content_a_history_id', dependent: :destroy, inverse_of: :content_a_history

          belongs_to :external_source, class_name: 'DataCycleCore::ExternalSystem'
          belongs_to :created_by_user, foreign_key: :created_by, class_name: 'DataCycleCore::User'
          belongs_to :updated_by_user, foreign_key: :updated_by, class_name: 'DataCycleCore::User'
          belongs_to :deleted_by_user, foreign_key: :deleted_by, class_name: 'DataCycleCore::User'
          belongs_to :representation_of, class_name: 'DataCycleCore::User'

          belongs_to :parent, class_name: self_class, foreign_key: 'is_part_of', inverse_of: :children, touch: false
          has_many :children, class_name: self_class, foreign_key: 'is_part_of', inverse_of: :parent, dependent: :destroy

          has_many :watch_list_data_hashes, as: :hashable, dependent: :destroy
          has_many :watch_lists, through: :watch_list_data_hashes

          has_many :subscriptions, as: :subscribable, dependent: :destroy
          has_many :data_link_content_items, as: :content
          has_many :indirect_data_links, through: :data_link_content_items
          has_many :data_links, as: :item, dependent: :destroy
          has_many :valid_write_links, -> { valid.writable }, class_name: 'DataCycleCore::DataLink', as: :item
          has_many :asset_contents, dependent: :destroy, as: :content_data
          has_many :assets, through: :asset_contents

          belongs_to :thing_template, inverse_of: :things, foreign_key: :template_name, primary_key: :template_name
          delegate :schema, :computed_schema_types, to: :thing_template
        end

        def data_links
          return DataCycleCore::DataLink.none if self == DataCycleCore::Thing::History

          DataCycleCore::DataLink.where(item_id: all.select(:id))
        end

        def thing_templates
          DataCycleCore::ThingTemplate.where(template_name: all.reorder(nil).select(:template_name))
        end

        def recursive_content_content_a
          return DataCycleCore::ContentContent.none if self == DataCycleCore::Thing::History

          DataCycleCore::ContentContent.where("content_contents.id IN (#{ActiveRecord::Base.send(:sanitize_sql_array, [recursive_content_content_a_query, id: all.pluck(:id)])})").order(order_a: :asc)
        end

        def classification_contents
          return DataCycleCore::ClassificationContent.none if self == DataCycleCore::Thing::History

          DataCycleCore::ClassificationContent.where(content_data_id: all.pluck(:id))
        end

        def collected_classification_contents
          return DataCycleCore::CollectedClassificationContent.none if self == DataCycleCore::Thing::History

          DataCycleCore::CollectedClassificationContent.where(thing_id: all.pluck(:id))
        end

        private

        def recursive_content_content_a_query
          <<-SQL.squish
            WITH RECURSIVE content_tree(id) AS (
              SELECT content_contents.id,
                content_contents.content_b_id
              FROM content_contents
              WHERE content_contents.content_a_id IN (:id)
              UNION
              SELECT content_contents.id,
                content_contents.content_b_id
              FROM content_contents
                INNER JOIN content_tree ON content_tree.content_b_id = content_contents.content_a_id
            )
            SELECT content_tree.id
            FROM content_tree
          SQL
        end
      end

      def valid_writable_links_by_receiver?(user)
        data_links = DataCycleCore::DataLink.valid.writable.by_receiver(user).joins("LEFT OUTER JOIN watch_list_data_hashes ON watch_list_data_hashes.watch_list_id = data_links.item_id AND watch_list_data_hashes.hashable_type = 'DataCycleCore::Thing'")

        data_links
          .where(item_type: 'DataCycleCore::Thing', item_id: id)
          .or(data_links.where(item_type: 'DataCycleCore::WatchList', watch_list_data_hashes: { hashable_id: id }))
          .any?
      end

      def display_classification_aliases(context)
        if classification_aliases.loaded?
          ca_query = classification_aliases
          ca_query = ca_query.includes(:classification_tree_label) unless classification_aliases.first&.association(:classification_tree_label)&.loaded?
          ca_query = ca_query.includes(:classification_alias_path) unless classification_aliases.first&.association(:classification_alias_path)&.loaded?
          ca_query.to_a.select { |ca| Array.wrap(ca.classification_tree_label&.visibility).intersection(Array.wrap(context)).any? }
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
          classification_aliases.where.not(id: primary_classification_aliases.select(:id))
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

      def is_related? # rubocop:disable Naming/PredicateName(RuboCop)
        content_content_b.except(:order).exists?
      end

      def has_related? # rubocop:disable Naming/PredicateName(RuboCop)
        content_content_a.except(:order).exists?
      end

      def has_cached_related_contents? # rubocop:disable Naming/PredicateName(RuboCop)
        cached_related_contents.exists?
      end

      def template_missing?
        thing_template.nil?
      end

      def require_template!
        raise ActiveRecord::RecordNotFound if thing_template.nil?

        self
      end

      def thing_template?
        !template_missing?
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

        query = self.class.where("#{self.class.table_name}.id IN (#{ActiveRecord::Base.send(:sanitize_sql_array, [
                                                                                              tree_query,
                                                                                              id:,
                                                                                              content_type_embedded: CONTENT_TYPE_EMBEDDED
                                                                                            ])})")
        query = query.where.not(content_type: CONTENT_TYPE_EMBEDDED) unless embedded
        query
      end

      def depending_contents
        raw_sql = <<-SQL.squish
          WITH RECURSIVE content_dependencies AS (
            SELECT ARRAY [content_content_links.content_a_id, content_content_links.content_b_id] content_ids
            FROM content_content_links
            WHERE content_content_links.content_b_id = :id::UUID
            UNION ALL
            SELECT content_content_links.content_a_id || content_dependencies.content_ids content_ids
            FROM content_content_links
              JOIN content_dependencies ON content_dependencies.content_ids [1] = content_content_links.content_b_id
              AND content_content_links.content_a_id <> ALL (content_dependencies.content_ids)
          )
          SELECT things.id
          FROM things
          WHERE EXISTS (
              SELECT 1
              FROM content_dependencies
              WHERE content_ids [1] = #{self.class.table_name}.#{self.class.primary_key}
            )
        SQL

        self.class
          .where(content_type: 'entity')
          .where("things.id IN (#{ActiveRecord::Base.send(:sanitize_sql_array, [raw_sql, id:])})")
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

        self.class.where("#{self.class.table_name}.id IN (#{ActiveRecord::Base.send(:sanitize_sql_array, [
                                                                                      tree_query,
                                                                                      id:,
                                                                                      content_type_embedded: CONTENT_TYPE_EMBEDDED
                                                                                    ])})")
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

        self.class.where("#{self.class.table_name}.id IN (#{ActiveRecord::Base.send(:sanitize_sql_array, [
                                                                                      tree_query,
                                                                                      id:,
                                                                                      content_type_embedded: CONTENT_TYPE_EMBEDDED
                                                                                    ])})")
      end

      def cached_related_contents
        return self.class.none if history?

        tree_query = <<-SQL.squish
          WITH RECURSIVE paths (content_b_id, content_a_id, PATH) AS (
            SELECT DISTINCT ON (c.content_a_id) c.content_b_id, c.content_a_id, ARRAY[c.content_b_id, c.content_a_id]
            FROM content_content_links c
            WHERE c.content_b_id = :id
            UNION ALL
            SELECT DISTINCT ON (d.content_a_id) d.content_b_id, d.content_a_id, p.path || ARRAY[d.content_a_id]
            FROM paths p
            INNER JOIN content_content_links d ON p.content_a_id = d.content_b_id
            WHERE d.content_a_id != ALL (p.path)
            AND ARRAY_LENGTH(p.path, 1) <= :depth
          )
          SELECT DISTINCT paths.content_a_id FROM paths
        SQL

        self.class.where("#{self.class.table_name}.id IN (#{ActiveRecord::Base.send(:sanitize_sql_array, [tree_query, id:, depth: DataCycleCore.cache_invalidation_depth])})")
      end

      def recursive_content_content_a
        return self.class.none if history?

        DataCycleCore::ContentContent.where("content_contents.id IN (#{ActiveRecord::Base.send(:sanitize_sql_array, [self.class.recursive_content_content_a_query, id:])})").order(order_a: :asc)
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
