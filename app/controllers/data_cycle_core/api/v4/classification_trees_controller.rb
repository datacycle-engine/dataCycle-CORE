# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ClassificationTreesController < ::DataCycleCore::Api::V4::ApiBaseController
        before_action :prepare_url_parameters

        include DataCycleCore::FilterConcern
        include DataCycleCore::FilterConceptConcern

        ALLOWED_FILTER_ATTRIBUTES = [:'dct:modified', :'dct:created', :'dct:deleted', :'skos:broader', :'skos:ancestors'].freeze
        ALLOWED_SORT_ATTRIBUTES = { 'dct:created' => 'created_at', 'dct:modified' => 'updated_at' }.freeze
        ALLOWED_FACET_SORT_ATTRIBUTES = { 'dc:thingCountWithSubtree' => 'thing_count_with_subtree', 'dc:thingCountWithoutSubtree' => 'thing_count_without_subtree' }.freeze
        VALIDATE_PARAMS_CONTRACT = MasterData::Contracts::ClassificationContract
        NULL_REGEX = /^NULL$/i

        def index
          @classification_tree_labels = ClassificationTreeLabel.where(internal: false).visible('api')

          if permitted_params.dig(:filter, :attribute).present?
            filter = permitted_params[:filter][:attribute].to_h.deep_symbolize_keys.slice(*ALLOWED_FILTER_ATTRIBUTES)
            @classification_tree_labels = @classification_tree_labels.with_deleted if filter.key?(:'dct:deleted')
            @classification_tree_labels = apply_filters(@classification_tree_labels, filter)
          end
          @classification_tree_labels = @classification_tree_labels.search(@full_text_search) if @full_text_search
          @classification_tree_labels = apply_ordering(@classification_tree_labels)
          @classification_tree_labels = apply_paging(@classification_tree_labels)
        end

        def show
          @classification_tree_label = ClassificationTreeLabel.find(permitted_params[:id])
        end

        def classifications
          @classification_tree_label = ClassificationTreeLabel.with_deleted.find(permitted_params[:id])

          build_concepts_search_query(@classification_tree_label.classification_aliases) do
            @classification_aliases = apply_concept_filters(@classification_aliases, permitted_params[:filter])
          end
        end

        def facets
          @classification_tree_label = ClassificationTreeLabel.find(permitted_params[:classification_tree_label_id])
          query = build_search_query
          min_count_without_subtree = (permitted_params[:min_count_without_subtree] || permitted_params[:minCountWithoutSubtree]).to_i
          min_count_without_subtree_sanitized = ActiveRecord::Base.connection.quote(min_count_without_subtree)
          min_count_with_subtree = (permitted_params[:min_count_with_subtree] || permitted_params[:minCountWithSubtree]).to_i
          min_count_with_subtree = [min_count_with_subtree, min_count_without_subtree].max
          min_count_with_subtree_sanitized = ActiveRecord::Base.connection.quote(min_count_with_subtree)
          join_type = min_count_with_subtree.positive? || min_count_without_subtree.positive? ? 'INNER' : 'LEFT'
          subquery = query.query.where('things.id = ccc1.thing_id AND ccc1.classification_tree_label_id = ?', permitted_params[:classification_tree_label_id]).except(*DataCycleCore::Filter::Common::Union::UNION_FILTER_EXCEPTS).select(1).to_sql

          join_sql = <<~SQL.squish
            #{join_type} JOIN LATERAL (SELECT ccc1.classification_alias_id,
              COUNT(DISTINCT ccc1.thing_id) AS thing_count_with_subtree,
              COUNT(DISTINCT ccc1.thing_id) filter (WHERE ccc1.link_type IN ('direct', 'related')) AS thing_count_without_subtree
              FROM collected_classification_contents ccc1
              WHERE ccc1.hidden = FALSE AND EXISTS (#{subquery})
              GROUP BY ccc1.classification_alias_id
            ) ccc ON ccc.classification_alias_id = classification_aliases.id
                AND COALESCE(ccc.thing_count_with_subtree, 0) >= #{min_count_with_subtree_sanitized}
                AND COALESCE(ccc.thing_count_without_subtree, 0) >= #{min_count_without_subtree_sanitized}
          SQL

          select_sql = <<~SQL.squish
            classification_aliases.*,
            COALESCE(ccc.thing_count_with_subtree, 0) AS thing_count_with_subtree,
            COALESCE(ccc.thing_count_without_subtree, 0) AS thing_count_without_subtree
          SQL

          @classification_aliases = DataCycleCore::ClassificationAlias
            .joins(join_sql)
            .where(
              DataCycleCore::ClassificationTree
                .where('classification_trees.classification_alias_id = classification_aliases.id')
                .where(classification_tree_label_id: permitted_params[:classification_tree_label_id])
                .select(1).arel.exists
            )
            .select(select_sql)

          # unset full_text_search for facets, as it interferes with ordering and is not needed
          @full_text_search = nil
          @language = Array.wrap(permitted_params[:conceptLanguage]) if permitted_params[:conceptLanguage].present?

          build_concepts_search_query(@classification_aliases) do
            # conceptFilter restricts the returned concepts (the content counts stay driven by +filter+, #43008)
            @classification_aliases = @classification_aliases.where(id: filtered_facet_concept_scope) if permitted_params[:conceptFilter].present?
          end

          # unset classification_trees_filter to render all classifications
          @classification_trees_parameters = []
          @classification_trees_filter = false
        end

        def by_external_key
          @external_key = external_params[:external_key]
          external_keys = @external_key&.split(',')&.map(&:strip)
          @external_source_id = external_params[:external_source_id]

          @classification_aliases = DataCycleCore::Classification
            .by_external_key(@external_source_id, external_keys)
            .primary_classification_aliases

          if permitted_params.dig(:filter, :attribute).present?
            filter = permitted_params[:filter][:attribute].to_h.deep_symbolize_keys.slice(*ALLOWED_FILTER_ATTRIBUTES)
            if filter.key?(:'dct:deleted')
              @classification_aliases = DataCycleCore::Classification
                .by_external_key(@external_source_id, external_keys).with_deleted
                .primary_classification_aliases.with_deleted
            end
            @classification_aliases = apply_filters(@classification_aliases, filter)
          end

          @classification_aliases = @classification_aliases.search(@full_text_search) if @full_text_search
          @classification_aliases = @classification_aliases.with_locale(@language) if @language.present?
          @classification_aliases = apply_ordering(@classification_aliases)
          @classification_aliases = apply_paging(@classification_aliases)
        end

        # +filter.search+/+filter.q+ may arrive as the {value, fields} hash form (allowed since #43008
        # loosened the filter permit). The concept +.search+ and similarity ordering both need a plain
        # term, so keep only the value here — otherwise ordering raises "can't quote Parameters".
        def prepare_url_parameters
          super
          @full_text_search = @full_text_search[:value] if @full_text_search.is_a?(ActionController::Parameters)
        end

        def permitted_parameter_keys
          super + [:id, :language, :conceptLanguage, :classification_id, :classification_ids, :classificationIds, :classification_tree_label_id, :min_count_with_subtree, :min_count_without_subtree, :minCountWithSubtree, :minCountWithoutSubtree] + [permitted_filter_parameters]
        end

        # Filter params are permitted as open hashes and validated by action-specific Dry contracts
        # (see #api_filter_contracts) instead of a hand-maintained allow-list. On facets, +filter+
        # selects the counted contents and +conceptFilter+ selects the returned concepts; on the
        # other actions +filter+ selects the returned concepts. See Redmine #43008.
        def permitted_filter_parameters
          return { filter: {}, conceptFilter: {} } if action_name == 'facets'

          { filter: {} }
        end

        private

        # Routes +filter+ (and +conceptFilter+ on facets) to the action-appropriate per-action contracts
        # (see #api_filter_contracts) instead of the single default +ApiFilterContract+. The rest of the
        # params validation stays in +ApiService#validate_api_params+.
        def validate_api_filter_params(validation_params)
          api_filter_contracts.each_with_object([]) do |(filter_key, contract_class), errors|
            next if validation_params&.dig(filter_key).blank?

            errors.concat(validate_api_filters(validation_params.delete(filter_key), [filter_key], contract_class.new))
          end
        end

        # Maps each permitted filter key to the Dry contract that validates it for the current action.
        def api_filter_contracts
          case action_name
          when 'facets'
            { filter: MasterData::Contracts::ApiFilterContract, conceptFilter: MasterData::Contracts::FacetConceptFilterContract }
          when 'index'
            { filter: MasterData::Contracts::ConceptSchemeFilterContract }
          else
            { filter: MasterData::Contracts::ConceptFilterContract }
          end
        end

        def external_params
          params.permit(:external_key, :external_source_id)
        end

        def apply_filters(query, filter)
          return super if action_name == 'facets'

          apply_concept_attribute_filters(query, filter)
        end

        # Applies the concept result-set filters (dct:* date ranges, skos:broader / skos:ancestors) to a
        # classification-alias / tree-label query. Used by the concept endpoints and, for +conceptFilter+,
        # by #facets (where #apply_filters itself delegates to the content-filter engine via +super+).
        def apply_concept_attribute_filters(query, filter)
          filter.each do |attribute_key, operator|
            attribute_path = case attribute_key
                             when :'dct:modified'
                               'updated_at'
                             when :'dct:created'
                               'created_at'
                             when :'dct:deleted'
                               'deleted_at'
                             when :'skos:broader'
                               'parent_classification_alias_id'
                             when :'skos:ancestors'
                               'ancestor_ids'
                             else
                               next
                             end
            operator.each do |k, v|
              if attribute_path == 'parent_classification_alias_id'
                query = apply_broader_filter(query, attribute_path, k, v)
              elsif attribute_path == 'ancestor_ids'
                query = apply_ancestor_filter(query, attribute_path, k, v)
              else
                query_string = apply_timestamp_query_string(v, "#{query.table.name}.#{attribute_path}")

                if k == :in
                  query = query.where(query_string)
                elsif k == :notIn
                  query = query.where.not(query_string)
                end
              end
            end
          end

          query
        end

        def apply_broader_filter(query, attribute_path, k, v)
          flattened_v = v.flat_map { |w| w.split(',') }.map(&:strip)
          clean_ids = flattened_v.grep_v(NULL_REGEX)
          query_strings = []

          if k == :in
            query_strings << "classification_trees.#{attribute_path} IN (?)" if clean_ids.present?
            query_strings << "classification_trees.#{attribute_path} IS NULL" if flattened_v.any?(NULL_REGEX)
            where_part = query_strings.join(' OR ')
          elsif k == :notIn
            query_strings << "classification_trees.#{attribute_path} NOT IN (?)" if clean_ids.present?
            if flattened_v.any?(NULL_REGEX)
              query_strings << "classification_trees.#{attribute_path} IS NOT NULL"
              where_part = query_strings.join(' AND ')
            else
              query_strings << "classification_trees.#{attribute_path} IS NULL"
              where_part = query_strings.join(' OR ')
            end
          end

          query.where(ActiveRecord::Base.send(:sanitize_sql_array, [where_part, clean_ids]))
        end

        def apply_ancestor_filter(query, attribute_path, k, v)
          flattened_v = v.flat_map { |w| w.split(',') }.map(&:strip)
          query = query.joins(:classification_alias_path)
          where_part = ActiveRecord::Base.send(:sanitize_sql_array, ["classification_alias_paths.#{attribute_path} && ARRAY[?]::UUID[]", flattened_v])

          if k == :in
            query.where(where_part)
          elsif k == :notIn
            query.where.not(where_part)
          end
        end

        # Applies the concept result-set filters (attribute + full-text) from +filter+ to +scope+, swapping
        # in the with-deleted alias scope of +@classification_tree_label+ when the filter targets
        # +dct:deleted+. Shared by #classifications (+filter+) and #facets (+conceptFilter+, via
        # #filtered_facet_concept_ids) so both endpoints filter concepts identically.
        def apply_concept_filters(scope, filter)
          filter = filter.to_h.deep_symbolize_keys

          if filter[:attribute].present?
            attribute_filter = filter[:attribute].to_h.deep_symbolize_keys.slice(*ALLOWED_FILTER_ATTRIBUTES)
            scope = @classification_tree_label.classification_aliases_with_deleted if attribute_filter.key?(:'dct:deleted')
            scope = apply_concept_attribute_filters(scope, attribute_filter)
          end

          search = concept_full_text_search(filter)
          scope = apply_full_text_search(scope, search) if search.present?

          scope
        end

        # Concept-id scope (within the current tree) matching +conceptFilter+, used by #facets to restrict
        # the returned concepts. Returned as a relation so it composes into +WHERE id IN (subquery)+ rather
        # than materializing every matching id into Ruby and shipping it back as a bind-heavy +IN (...)+ list.
        # Runs the concept filters against +classification_aliases+ (which joins +classification_trees+, so
        # skos:broader resolves) rather than against the content-count query. +reorder(nil)+ drops any
        # default ordering, which is meaningless in an +IN+ subquery (and would otherwise be dead work).
        def filtered_facet_concept_scope
          apply_concept_filters(@classification_tree_label.classification_aliases, permitted_params[:conceptFilter])
            .reorder(nil).select(:id)
        end

        # Full-text term from a concept filter, accepting both the plain-string and the {value, fields} forms.
        def concept_full_text_search(filter)
          value = filter[:search] || filter[:q]
          value.is_a?(::Hash) ? value[:value] : value
        end

        def apply_full_text_search(query, search)
          query.search(search)
        end

        def transform_sort_param(key, order)
          allowed_sort_attributes = ALLOWED_SORT_ATTRIBUTES.dup
          allowed_sort_attributes.merge!(ALLOWED_FACET_SORT_ATTRIBUTES) if action_name == 'facets'

          return unless allowed_sort_attributes.key?(key)

          "#{allowed_sort_attributes[key]} #{order} NULLS LAST, id ASC"
        end
      end
    end
  end
end
