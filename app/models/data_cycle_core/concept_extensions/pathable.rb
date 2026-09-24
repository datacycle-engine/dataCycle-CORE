# frozen_string_literal: true

module DataCycleCore
  module ConceptExtensions
    # Where a concept sits in its scheme: the materialised path it is reachable through, and the
    # writes that move it somewhere else.
    #
    # concept_paths and concept_paths_transitive are trigger-maintained projections of `concepts` and
    # the `broader` concept_links, so every method here either reads a path or writes a link and lets
    # the triggers catch up.
    module Pathable
      extend ActiveSupport::Concern

      included do
        belongs_to :concept_path, primary_key: :id, foreign_key: :id, inverse_of: false

        # all three are removed by the FK ON DELETE CASCADE on concept_id
        has_many :concept_paths_transitive

        has_many :descendant_paths, ->(c) { unscope(:where).where('ancestor_ids @> ARRAY[?]::uuid[]', c.id) }, class_name: 'DataCycleCore::ConceptPath', inverse_of: false
        has_many :descendants, through: :descendant_paths, source: :concept

        delegate :full_path_names, to: :concept_path

        scope :by_full_path_arrays, ->(full_paths) { full_paths.blank? ? none : includes(:concept_path).where('concept_paths.full_path_names IN (?)', Array.wrap(full_paths).map { |p| p.map { |v| v.to_s.strip }.reverse.to_pg_array }).references(:concept_path) } # rubocop:disable Rails/WhereEquals
        scope :by_full_paths, ->(full_paths) { full_paths.blank? ? none : includes(:concept_path).where('concept_paths.full_path_names IN (?)', Array.wrap(full_paths).map { |p| p.split('>').map(&:strip).reverse.to_pg_array }).references(:concept_path) } # rubocop:disable Rails/WhereEquals
        scope :search, ->(q) { includes(:concept_path).where("ARRAY_TO_STRING(ARRAY_REVERSE(full_path_names), ' > ') ILIKE :q OR (concepts.description_i18n ->> :locale) ILIKE :q OR (concepts.name_i18n ->> :locale) ILIKE :q", { locale: I18n.locale, q: "%#{q.squish.gsub(/\s/, '%')}%" }).references(:concept_path) }
        scope :order_by_similarity, lambda { |term|
          max_cardinality = DataCycleCore::ConceptPath.pluck(Arel.sql('MAX(CARDINALITY(full_path_names))')).max
          order_string = (1..max_cardinality).map { |c| "COALESCE(10 ^ #{max_cardinality - c} * (1 - (full_path_names[#{c}] <-> :term)), 0)" }.join(' + ')
          order_string += ' DESC'

          joins(:concept_path).reorder(nil).order(
            Arel.sql(ActiveRecord::Base.send(:sanitize_sql_array, [order_string, { term: }]))
          )
        }
      end

      class_methods do
        def with_descendants
          query = is_a?(ActiveRecord::Relation) ? self : all

          query.unscoped
            .joins(:concept_path)
            .where('full_path_ids && ARRAY[?]::uuid[]', query.pluck(:id))
        end

        def custom_find_by_full_path(full_path)
          includes(:concept_path)
            .where("ARRAY_TO_STRING(ARRAY_REVERSE(full_path_names), ' > ') ILIKE ?", full_path)
            .references(:concept_paths)
            .first
        end

        def custom_find_by_full_path!(full_path)
          custom_find_by_full_path(full_path) || raise(ActiveRecord::RecordNotFound)
        end
      end

      def full_path
        concept_path&.full_path_names&.reverse&.join(' > ')
      end

      # The concepts above this one, nearest first. concept_paths.ancestor_ids holds exactly them -
      # neither this concept nor its scheme, which is why the scheme is asked for separately wherever
      # a display needs it (see ConceptScheme#ancestors, which is empty by the same token).
      def ancestors
        return [] unless concept_path

        concept_path.ancestor_concepts
      end

      def find_content_template(templates)
        template = templates.find { |t| t.schema&.dig('properties', 'data_type', 'default_value') == name }

        return template if template.present?

        parent&.find_content_template(templates)
      end

      # Moves this concept under +new_path+, creating the missing intermediate concepts. When the path
      # already resolves to a concept, this one is folded into it instead.
      #
      # @param new_path [Array<String>, String] scheme name or concept id, then the names below it
      # @param destroy_children [Boolean] fold this concept's descendants into it before moving
      # @return [DataCycleCore::Concept, nil] the concept the caller ends up at
      def move_to_path(new_path, destroy_children: false)
        return if new_path.blank?

        new_path = Array.wrap(new_path)

        if new_path.first.uuid?
          new_concept = DataCycleCore::Concept.find_by(id: new_path.first)
          target_scheme = new_concept&.concept_scheme
        else
          target_scheme = DataCycleCore::ConceptScheme.find_by(name: new_path.first)
          new_concept = DataCycleCore::Concept.includes(:concept_path).find_by(concept_paths: { full_path_names: new_path.reverse })
        end

        return if target_scheme.nil?

        transaction do
          ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')

          if new_concept.nil?
            new_parent = target_scheme.create_concept(*new_path[1...-1].map { |c| { name: c } })

            merge_children_into_self if destroy_children
            move_to_scheme(new_parent&.id, target_scheme.id)
            new_concept = self
          else
            merge_with_children(new_concept, destroy_children:)
          end
        end

        new_concept
      end

      def move_after(target_scheme, previous_sibling, parent_concept = nil)
        parent_concept = previous_sibling&.parent if parent_concept.nil?

        transaction do
          ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')
          move_to_scheme(parent_concept&.id, target_scheme.id)
          update_columns(updated_at: Time.zone.now, order_a: previous_sibling&.reload&.order_a || parent_concept&.reload&.order_a || 0)
        end
      end

      # Re-parents this concept. The subtree follows on its own: concept_scheme_id is a column per
      # concept, and concepts_propagate_scheme_trigger rewrites the descendants' copy.
      #
      # @param parent_concept_id [String, nil] nil makes this concept a root of +concept_scheme_id+
      def move_to_scheme(parent_concept_id, concept_scheme_id)
        return if concept_scheme_id.nil?

        # A nil +parent_concept_id+ makes this concept a root of its scheme, which is the NULL parent
        # its `broader` link then carries - the link itself stays, see DataCycleCore::ConceptLink.
        parent_concept_link.update(parent_id: parent_concept_id)
        scheme_changed = self.concept_scheme_id != concept_scheme_id
        update_columns(concept_scheme_id:, updated_at: Time.zone.now) if scheme_changed

        return unless parent_concept_link.saved_changes? || scheme_changed

        add_things_cache_invalidation_job
        add_things_search_update_job
        add_things_webhooks_job_update
        # no callback covers a move: the writes land on concept_links and on the descendants,
        # and move_after bypasses the concept's own with update_columns. Reloaded because the
        # lines above can memoize the scheme from before the move.
        add_linked_things_computed_properties_job(reload_concept_scheme&.name)
      end
    end
  end
end
