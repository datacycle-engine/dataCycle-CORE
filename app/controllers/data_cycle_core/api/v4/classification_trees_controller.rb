# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ClassificationTreesController < ::DataCycleCore::Api::V4::ApiBaseController
        include DataCycleCore::ApiService
        before_action :prepare_url_parameters

        ALLOWED_FILTER_ATTRIBUTES = [:modifiedAt, :createdAt, :deletedAt].freeze
        ALLOWED_SORT_ATTRIBUTES = { created: 'created_at', modified: 'updated_at' }.freeze

        def index
          @classification_tree_labels = ClassificationTreeLabel.where(internal: false).visible('api')

          if permitted_params.dig(:filter, :attribute).present?
            filter = permitted_params[:filter][:attribute].to_h.deep_symbolize_keys.select { |k, _v| ALLOWED_FILTER_ATTRIBUTES.include?(k) }
            @classification_tree_labels = @classification_tree_labels.with_deleted if filter.key?(:deletedAt)
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
          if @classification_tree_label.visible?('api')
            @classification_id = permitted_params[:classification_id] || nil

            if @classification_id.present?
              @classification_aliases = DataCycleCore::ClassificationAlias.where(id: @classification_id) # .with_descendants
            else
              @classification_aliases = @classification_tree_label.classification_aliases
            end

            if permitted_params.dig(:filter, :attribute).present?
              filter = permitted_params[:filter][:attribute].to_h.deep_symbolize_keys.select { |k, _v| ALLOWED_FILTER_ATTRIBUTES.include?(k) }
              @classification_aliases = @classification_aliases.with_deleted if filter.key?(:deletedAt)
              @classification_aliases = apply_filters(@classification_aliases, filter)
            end

            @classification_aliases = apply_ordering(@classification_aliases)
            @classification_aliases = apply_paging(@classification_aliases)
          else
            @classification_tree_label = nil
          end
        end

        def prepare_url_parameters
          @url_parameters = permitted_params.reject { |k, _| k == 'format' }
          @include_parameters = parse_tree_params(permitted_params.dig(:include))
          @fields_parameters = parse_tree_params(permitted_params.dig(:fields))
          @field_filter = @fields_parameters.present?
          @language = parse_language(permitted_params.dig(:language)).presence || Array(I18n.available_locales.first.to_s)
          @api_subversion = permitted_params.dig(:api_subversion) if DataCycleCore.main_config.dig(:api, :v4, :subversions)&.include?(permitted_params.dig(:api_subversion))
          @api_version = 4
        end

        def permitted_parameter_keys
          super + [:id, :include, :fields, :format, :language, :classification_id, :sort] + [permitted_filter_parameters]
        end

        def permitted_filter_parameters
          {
            filter: [
              {
                attribute: {
                  modifiedAt: attribute_filter_operations,
                  createdAt: attribute_filter_operations,
                  deletedAt: attribute_filter_operations
                }
              }
            ]
          }
        end

        private

        def apply_filters(query, filter)
          filter.each do |attribute_key, operator|
            attribute_path = case attribute_key
                             when :modifiedAt
                               'updated_at'
                             when :createdAt
                               'created_at'
                             when :deletedAt
                               'deleted_at'
                             else
                               next
                             end
            operator.each do |k, v|
              query_string = apply_query_string(v, "#{query.table.name}.#{attribute_path}")
              if k == :in
                query = query.where(query_string)
              elsif k == :notIn
                query = query.where.not(query_string)
              end
            end
          end
          query
        end

        def apply_ordering(query)
          order_query = permitted_params.dig(:sort)&.split(',')&.map { |sort|
            if sort.starts_with?('-')
              transform_sort_param(sort[1..-1], 'DESC')
            elsif sort.starts_with?('+')
              transform_sort_param(sort[1..-1], 'ASC')
            else
              transform_sort_param(sort, 'ASC')
            end
          }&.reject(&:blank?)
          order_query = ['updated_at ASC'] if order_query.blank?
          query.except(:order).order(ActiveRecord::Base.send(:sanitize_sql_for_order, Arel.sql(order_query.join(', '))))
        end

        def transform_sort_param(key, order)
          return unless ALLOWED_SORT_ATTRIBUTES.key?(key.to_sym)
          "#{ALLOWED_SORT_ATTRIBUTES.dig(key.to_sym)} #{order}"
        end

        def apply_query_string(values, attribute_path)
          date_range = "[#{date_from_single_value(values.dig(:min))&.beginning_of_day},#{date_from_single_value(values.dig(:max))&.end_of_day}]"
          ClassificationTreeLabel.send(:sanitize_sql_for_conditions, ["?::daterange @> #{attribute_path}::date", date_range])
        end

        def date_from_single_value(value)
          return if value.blank?
          return value if value.is_a?(::Date)
          DataCycleCore::MasterData::DataConverter.string_to_datetime(value)
        end
      end
    end
  end
end
