# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ClassificationTreesController < ::DataCycleCore::Api::V4::ApiBaseController
        before_action :prepare_url_parameters

        include DataCycleCore::FilterConcern

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
          @classification_tree_labels = apply_ordering(@classification_tree_labels)
          @classification_tree_labels = apply_paging(@classification_tree_labels)
        end

        def show
          @classification_tree_label = ClassificationTreeLabel.find(permitted_params[:id])
        end

        def classifications
          @classification_tree_label = ClassificationTreeLabel.with_deleted.find(permitted_params[:id])
          @classification_id = permitted_params[:classification_id] || nil

          if @classification_id.present?
            @classification_aliases = @classification_tree_label.classification_aliases.where(id: @classification_id)
            raise ActiveRecord::RecordNotFound if @classification_aliases.blank?
          else
            @classification_aliases = @classification_tree_label.classification_aliases.includes(:classification_tree_label)
          end

          if permitted_params.dig(:filter, :attribute).present?
            filter = permitted_params[:filter][:attribute].to_h.deep_symbolize_keys.slice(*ALLOWED_FILTER_ATTRIBUTES)
            @classification_aliases = @classification_tree_label.classification_aliases_with_deleted if filter.key?(:'dct:deleted')
            @classification_aliases = apply_filters(@classification_aliases, filter)
          end

          @classification_aliases = @classification_aliases.includes(:classification_polygons) if helpers.included_attribute?('geo', @fields_parameters + @include_parameters)

          @classification_aliases = @classification_aliases.search(@full_text_search) if @full_text_search
          @classification_aliases = apply_ordering(@classification_aliases)
          @classification_aliases = apply_paging(@classification_aliases)
        end

        def facets
          @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find(permitted_params[:classification_tree_label_id])
          query = build_search_query

          min_count_without_subtree = (permitted_params[:min_count_without_subtree] || permitted_params[:minCountWithoutSubtree]).to_i
          min_count_without_subtree_sanitized = ActiveRecord::Base.connection.quote(min_count_without_subtree)
          min_count_with_subtree = (permitted_params[:min_count_with_subtree] || permitted_params[:minCountWithSubtree]).to_i
          min_count_with_subtree = [min_count_with_subtree, min_count_without_subtree].max
          min_count_with_subtree_sanitized = ActiveRecord::Base.connection.quote(min_count_with_subtree)
          join_type = min_count_with_subtree.positive? || min_count_without_subtree.positive? ? 'INNER' : 'LEFT'
          subquery = query.query.where('things.id = ccc1.thing_id AND ccc1.classification_tree_label_id = ?', @classification_tree_label.id).except(*DataCycleCore::Filter::Common::Union::UNION_FILTER_EXCEPTS).select(1).to_sql

          join_sql = <<~SQL.squish
            #{join_type} JOIN LATERAL (SELECT ccc1.classification_alias_id,
              COUNT(DISTINCT ccc1.thing_id) AS thing_count_with_subtree,
              COUNT(DISTINCT ccc1.thing_id) filter (WHERE ccc1.link_type IN ('direct', 'related')) AS thing_count_without_subtree
              FROM collected_classification_contents ccc1
              WHERE EXISTS (#{subquery})
              GROUP BY ccc1.classification_alias_id
            ) ccc ON ccc.classification_alias_id = classification_aliases.id
                AND COALESCE(ccc.thing_count_with_subtree, 0) >= #{min_count_with_subtree_sanitized}
                AND COALESCE(ccc.thing_count_without_subtree, 0) >= #{min_count_without_subtree_sanitized}
          SQL

          select_sql = <<-SQL.squish
            classification_aliases.*,
            COALESCE(ccc.thing_count_with_subtree, 0) AS thing_count_with_subtree,
            COALESCE(ccc.thing_count_without_subtree, 0) AS thing_count_without_subtree
          SQL

          @classification_aliases = DataCycleCore::ClassificationAlias
            .joins(join_sql)
            .where(
              DataCycleCore::ClassificationTree
                .where('classification_trees.classification_alias_id = classification_aliases.id')
                .where(classification_tree_label_id: @classification_tree_label.id)
                .select(1).arel.exists
            )
            .select(select_sql)

          @classification_id = permitted_params[:classification_id]
          if @classification_id.present?
            @classification_aliases = @classification_aliases.where(id: @classification_id)
            raise ActiveRecord::RecordNotFound if @classification_aliases.blank?
          elsif permitted_params[:classification_ids].present?
            @classification_aliases = @classification_aliases.where(id: permitted_params[:classification_ids].split(','))
          end

          @classification_aliases = apply_order_query(@classification_aliases, permitted_params[:sort])
          @classification_aliases = apply_paging(@classification_aliases)
          @classification_aliases = @classification_aliases.includes(:classification_tree_label)

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
          @classification_aliases = apply_ordering(@classification_aliases)
          @classification_aliases = apply_paging(@classification_aliases)
        end

        def permitted_parameter_keys
          super + [:id, :language, :classification_id, :classification_ids, :classification_tree_label_id, :min_count_with_subtree, :min_count_without_subtree, :minCountWithSubtree, :minCountWithoutSubtree] + [permitted_filter_parameters]
        end

        def permitted_filter_parameters
          if action_name == 'index'
            {
              filter: [
                {
                  attribute: {
                    'dct:modified': attribute_filter_operations,
                    'dct:created': attribute_filter_operations,
                    'dct:deleted': attribute_filter_operations
                  }
                }
              ]
            }
          elsif action_name == 'facets'
            {
              filter: {}
            }
          else
            {
              filter: [
                :search,
                :q,
                {
                  attribute: {
                    'dct:modified': attribute_filter_operations,
                    'dct:created': attribute_filter_operations,
                    'dct:deleted': attribute_filter_operations,
                    'skos:broader': concept_classification_filter_operations,
                    'skos:ancestors': concept_classification_filter_operations
                  }
                }
              ]
            }
          end
        end

        private

        def concept_classification_filter_operations
          {
            in: [],
            notIn: []
          }
        end

        def external_params
          params.permit(:external_key, :external_source_id)
        end

        def apply_filters(query, filter)
          return super if action_name == 'facets'

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
          clean_ids = v.grep_v(NULL_REGEX)
          query_strings = []

          if k == :in
            query_strings << "classification_trees.#{attribute_path} IN (?)" if clean_ids.present?
            query_strings << "classification_trees.#{attribute_path} IS NULL" if v.any?(NULL_REGEX)
            where_part = query_strings.join(' OR ')
          elsif k == :notIn
            query_strings << "classification_trees.#{attribute_path} NOT IN (?)" if clean_ids.present?
            if v.any?(NULL_REGEX)
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
          query = query.joins(:classification_alias_path)
          where_part = ActiveRecord::Base.send(:sanitize_sql_array, ["classification_alias_paths.#{attribute_path} && ARRAY[?]::UUID[]", v])

          if k == :in
            query.where(where_part)
          elsif k == :notIn
            query.where.not(where_part)
          end
        end

        def apply_full_text_search(query, search)
          query.search(search)
        end

        def apply_ordering(query)
          apply_order_query(query, permitted_params[:sort], @full_text_search)
        end

        def apply_order_query(query, order_params, full_text_search = '')
          order_query = []
          order_params&.split(',')&.each do |sort|
            key, order = key_with_ordering(sort)
            order_query << transform_sort_param(key, order)
          end
          order_query = order_query&.reject(&:blank?)

          if order_query.blank?
            query = query.reorder(nil)
            query = query.order_by_similarity(full_text_search) if full_text_search.present?

            query = case query
                    when DataCycleCore::ClassificationAlias.const_get(:ActiveRecord_AssociationRelation), DataCycleCore::ClassificationAlias.const_get(:ActiveRecord_Relation)
                      query.order(order_a: :asc, id: :asc)
                    else
                      query.order(updated_at: :desc, id: :asc)
                    end

            return query
          end

          query.reorder(nil).order(ActiveRecord::Base.send(:sanitize_sql_for_order, Arel.sql(order_query.join(', '))))
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
