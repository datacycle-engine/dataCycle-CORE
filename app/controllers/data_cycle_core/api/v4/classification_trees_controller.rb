# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ClassificationTreesController < ::DataCycleCore::Api::V4::ApiBaseController
        before_action :prepare_url_parameters

        ALLOWED_FILTER_ATTRIBUTES = [:'dct:modified', :'dct:created', :'dct:deleted'].freeze
        ALLOWED_SORT_ATTRIBUTES = { 'dct:created': 'created_at', 'dct:modified': 'updated_at' }.freeze

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
            @classification_aliases = @classification_tree_label.classification_aliases
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

        def permitted_parameter_keys
          super + [:id, :language, :classification_id] + [permitted_filter_parameters]
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

        def apply_filters(query, filter)
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
            query = query.order_by_similarity(full_text_search) if full_text_search.present?
            query = query.order(ActiveRecord::Base.send(:sanitize_sql_for_order, Arel.sql('updated_at DESC')))
            return query
          end
          query.except(:order).order(ActiveRecord::Base.send(:sanitize_sql_for_order, Arel.sql(order_query.join(', '))))
        end

        def transform_sort_param(key, order)
          return unless ALLOWED_SORT_ATTRIBUTES.key?(key.to_sym)
          "#{ALLOWED_SORT_ATTRIBUTES.dig(key.to_sym)} #{order} NULLS LAST"
        end
      end
    end
  end
end
