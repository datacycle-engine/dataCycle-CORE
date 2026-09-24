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
          filter = permitted_params.dig(:filter, :attribute)&.to_h&.deep_symbolize_keys&.slice(*ALLOWED_FILTER_ATTRIBUTES)
          @concept_schemes = (filter&.key?(:'dct:deleted') ? ConceptScheme::History : ConceptScheme).where(internal: false).visible('api')
          @concept_schemes = apply_filters(@concept_schemes, filter) if filter.present?
          @concept_schemes = @concept_schemes.search(@full_text_search) if @full_text_search
          @concept_schemes = apply_ordering(@concept_schemes)
          @concept_schemes = apply_paging(@concept_schemes)
        end

        def show
          @concept_scheme = ConceptScheme.find(permitted_params[:id])
        end

        def classifications
          @concept_scheme = ConceptScheme.find_including_history(permitted_params[:id])
          filter = permitted_params[:filter].to_h.deep_symbolize_keys

          build_concepts_search_query(concept_base_scope(filter)) do
            @concepts = apply_concept_filters(@concepts, filter)
          end
        end

        def facets
          @concept_scheme = ConceptScheme.find(permitted_params[:classification_tree_label_id])
          query = build_search_query
          min_count_without_subtree = (permitted_params[:min_count_without_subtree] || permitted_params[:minCountWithoutSubtree]).to_i
          min_count_with_subtree = (permitted_params[:min_count_with_subtree] || permitted_params[:minCountWithSubtree]).to_i
          @concepts = DataCycleCore::Concept.thing_counts_for_tree(
            concept_scheme_id: permitted_params[:classification_tree_label_id],
            query: query.query,
            min_count_with_subtree:,
            min_count_without_subtree:
          )

          # unset full_text_search for facets, as it interferes with ordering and is not needed
          @full_text_search = nil
          @language = Array.wrap(permitted_params[:conceptLanguage]) if permitted_params[:conceptLanguage].present?

          build_concepts_search_query(@concepts) do
            # conceptFilter restricts the returned concepts (the content counts stay driven by +filter+, #43008)
            @concepts = @concepts.where(id: filtered_facet_concept_scope) if permitted_params[:conceptFilter].present?
          end

          # unset classification_trees_filter to render all classifications
          @classification_trees_parameters = []
          @classification_trees_filter = false
        end

        def by_external_key
          @external_key = external_params[:external_key]
          external_keys = @external_key&.split(',')&.map(&:strip)
          @external_source_id = external_params[:external_source_id]

          filter = permitted_params.dig(:filter, :attribute)&.to_h&.deep_symbolize_keys&.slice(*ALLOWED_FILTER_ATTRIBUTES)
          @concepts = concepts_by_external_key(external_keys, deleted: filter&.key?(:'dct:deleted'))
          @concepts = apply_filters(@concepts, filter) if filter.present?

          @concepts = @concepts.search(@full_text_search) if @full_text_search
          @concepts = @concepts.with_locale(@language) if @language.present?
          @concepts = apply_ordering(@concepts)
          @concepts = apply_paging(@concepts)
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
                               'parent_id'
                             when :'skos:ancestors'
                               'ancestor_ids'
                             else
                               next
                             end
            operator.each do |k, v|
              if attribute_path == 'parent_id'
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

        # The broader concept is the parent of the concept's `broader` link, so the filter joins
        # concept_links where it used to read classification_trees.parent_classification_alias_id.
        def apply_broader_filter(query, attribute_path, k, v)
          query = query.joins(:parent_concept_link)
          flattened_v = v.flat_map { |w| w.split(',') }.map(&:strip)
          clean_ids = flattened_v.grep_v(NULL_REGEX)
          query_strings = []

          if k == :in
            query_strings << "concept_links.#{attribute_path} IN (?)" if clean_ids.present?
            query_strings << "concept_links.#{attribute_path} IS NULL" if flattened_v.any?(NULL_REGEX)
            where_part = query_strings.join(' OR ')
          elsif k == :notIn
            query_strings << "concept_links.#{attribute_path} NOT IN (?)" if clean_ids.present?
            if flattened_v.any?(NULL_REGEX)
              query_strings << "concept_links.#{attribute_path} IS NOT NULL"
              where_part = query_strings.join(' AND ')
            else
              query_strings << "concept_links.#{attribute_path} IS NULL"
              where_part = query_strings.join(' OR ')
            end
          end

          query.where(ActiveRecord::Base.send(:sanitize_sql_array, [where_part, clean_ids]))
        end

        def apply_ancestor_filter(query, attribute_path, k, v)
          flattened_v = v.flat_map { |w| w.split(',') }.map(&:strip)
          query = query.joins(:concept_path)
          where_part = ActiveRecord::Base.send(:sanitize_sql_array, ["concept_paths.#{attribute_path} && ARRAY[?]::UUID[]", flattened_v])

          if k == :in
            query.where(where_part)
          elsif k == :notIn
            query.where.not(where_part)
          end
        end

        # Applies the concept result-set filters (attribute + full-text) from +filter+ to +scope+.
        # Shared by #classifications (+filter+) and #facets (+conceptFilter+, via
        # #filtered_facet_concept_scope) so both endpoints filter concepts identically.
        def apply_concept_filters(scope, filter)
          filter = filter.to_h.deep_symbolize_keys

          if filter[:attribute].present?
            attribute_filter = filter[:attribute].to_h.deep_symbolize_keys.slice(*ALLOWED_FILTER_ATTRIBUTES)
            scope = apply_concept_attribute_filters(scope, attribute_filter)
          end

          search = concept_full_text_search(filter)
          scope = apply_full_text_search(scope, search) if search.present?

          scope
        end

        # Concept-id scope (within the current tree) matching +conceptFilter+, used by #facets to restrict
        # the returned concepts. Returned as a relation so it composes into +WHERE id IN (subquery)+ rather
        # than materializing every matching id into Ruby and shipping it back as a bind-heavy +IN (...)+ list.
        # Runs the concept filters against the scheme's concepts rather than against the content-count
        # query. +reorder(nil)+ drops any default ordering, which is meaningless in an +IN+ subquery
        # (and would otherwise be dead work).
        def filtered_facet_concept_scope
          apply_concept_filters(@concept_scheme.concepts, permitted_params[:conceptFilter])
            .reorder(nil).select(:id)
        end

        # A concept carries external_system_id and external_key itself; the pair used to sit on the
        # classification and needed the hop to its primary alias. The route makes +external_key+
        # optional, so an empty pair has to answer with nothing rather than with every concept of the
        # system that carries no key.
        def concepts_by_external_key(external_keys, deleted:)
          model = deleted ? Concept::History : Concept
          return model.none if @external_source_id.blank? || external_keys.blank?

          model.where(external_system_id: @external_source_id, external_key: external_keys)
        end

        # Concepts have carried no deleted_at since Redmine #41458: a dct:deleted filter reads
        # concept_histories, where concept_scheme_id survives as a plain column even once the scheme
        # itself is gone.
        def concept_base_scope(filter)
          return Concept::History.where(concept_scheme_id: @concept_scheme.id) if filter.dig(:attribute, :'dct:deleted').present?
          return Concept.none if @concept_scheme.is_a?(ConceptScheme::History)

          @concept_scheme.concepts
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
