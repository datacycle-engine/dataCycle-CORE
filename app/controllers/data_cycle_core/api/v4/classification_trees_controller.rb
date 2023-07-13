# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ClassificationTreesController < ::DataCycleCore::Api::V4::ApiBaseController
        before_action :prepare_url_parameters

        include DataCycleCore::Filter

        ALLOWED_FILTER_ATTRIBUTES = [:'dct:modified', :'dct:created', :'dct:deleted'].freeze
        ALLOWED_SORT_ATTRIBUTES = { 'dct:created' => 'created_at', 'dct:modified' => 'updated_at' }.freeze
        ALLOWED_FACET_SORT_ATTRIBUTES = { 'dc:thingCountWithSubtree' => 'thing_count_with_subtree', 'dc:thingCountwithoutSubtree' => 'thing_count_without_subtree' }.freeze

        def index
          @classification_tree_labels = ClassificationTreeLabel.where(internal: false).visible('api')

          if permitted_params.dig(:filter, :attribute).present?
            filter = permitted_params[:filter][:attribute].to_h.deep_symbolize_keys.select { |k, _v| ALLOWED_FILTER_ATTRIBUTES.include?(k) }
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
            @classification_aliases = DataCycleCore::ClassificationAlias.where(id: @classification_id) # .with_descendants
            raise ActiveRecord::RecordNotFound if @classification_aliases.blank?
          else
            @classification_aliases = @classification_tree_label.classification_aliases.includes(:classification_tree_label)
          end

          if permitted_params.dig(:filter, :attribute).present?
            filter = permitted_params[:filter][:attribute].to_h.deep_symbolize_keys.select { |k, _v| ALLOWED_FILTER_ATTRIBUTES.include?(k) }
            @classification_aliases = @classification_tree_label.classification_aliases_with_deleted if filter.key?(:'dct:deleted')
            @classification_aliases = apply_filters(@classification_aliases, filter)
          end

          @classification_aliases = @classification_aliases.search(@full_text_search) if @full_text_search
          @classification_aliases = apply_ordering(@classification_aliases)
          @classification_aliases = apply_paging(@classification_aliases)
        end

        def facets
          @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find(permitted_params[:classification_tree_label_id])

          query = build_search_query

          join_sql = "LEFT OUTER JOIN (SELECT ccc1.* FROM collected_classification_contents ccc1 WHERE EXISTS (#{query.query.where('things.id = ccc1.thing_id').except(*DataCycleCore::Filter::Common::Union::UNION_FILTER_EXCEPTS).select(1).to_sql})) ccc ON ccc.classification_alias_id = classification_aliases.id"

          select_sql = <<-SQL.squish
            classification_aliases.*,
            COUNT(DISTINCT ccc.thing_id) AS thing_count_with_subtree,
            COUNT(DISTINCT ccc.thing_id) filter (WHERE ccc.direct = TRUE) AS thing_count_without_subtree
          SQL

          @classification_aliases = DataCycleCore::ClassificationAlias
            .where(
              DataCycleCore::ClassificationTree
                .where('classification_trees.classification_alias_id = classification_aliases.id')
                .where(classification_tree_label_id: @classification_tree_label.id)
                .select(1).arel.exists
            )
            .joins(join_sql)
            .select(select_sql)
          .group(:id)

          @classification_id = permitted_params[:classification_id]
          if @classification_id.present?
            @classification_aliases = @classification_aliases.where(id: @classification_id)
            raise ActiveRecord::RecordNotFound if @classification_aliases.blank?
          end

          @classification_aliases = apply_order_query(@classification_aliases, permitted_params.dig(:sort))
          @classification_aliases = apply_paging(@classification_aliases)
          @classification_aliases = @classification_aliases.includes(:classification_tree_label)
        end

        def by_external_key
          @external_key = external_params[:external_key]
          external_keys = @external_key&.split(',')&.map(&:strip)
          @external_source_id = external_params[:external_source_id]

          @classification_aliases = DataCycleCore::Classification
            .by_external_key(@external_source_id, external_keys)
            .primary_classification_aliases

          if permitted_params.dig(:filter, :attribute).present?
            filter = permitted_params[:filter][:attribute].to_h.deep_symbolize_keys.select { |k, _v| ALLOWED_FILTER_ATTRIBUTES.include?(k) }
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
          super + [:id, :language, :classification_id, :classification_tree_label_id] + [permitted_filter_parameters]
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
          else
            {
              filter: [
                :search,
                :q,
                {
                  attribute: {
                    'dct:modified': attribute_filter_operations,
                    'dct:created': attribute_filter_operations,
                    'dct:deleted': attribute_filter_operations
                  }
                }
              ]
            }
          end
        end

        private

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
                             else
                               next
                             end
            operator.each do |k, v|
              query_string = apply_timestamp_query_string(v, "#{query.table.name}.#{attribute_path}")
              if k == :in
                query = query.where(query_string)
              elsif k == :notIn
                query = query.where.not(query_string)
              end
            end
          end
          query
        end

        def apply_full_text_search(query, search)
          query = query.search(search)
          query
        end

        def apply_ordering(query)
          apply_order_query(query, permitted_params.dig(:sort), @full_text_search)
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
          "#{allowed_sort_attributes.dig(key)} #{order} NULLS LAST, id ASC"
        end
      end
    end
  end
end
