# frozen_string_literal: true

module DataCycleCore
  module FilterConceptConcern
    extend ActiveSupport::Concern

    private

    def build_concepts_search_query(base_query)
      @classification_id = permitted_params[:classification_id]
      @concepts = base_query
      @concepts = @concepts.includes(:concept_scheme)

      if @classification_id.present?
        @concepts = @concepts.where(id: @classification_id)
        raise ActiveRecord::RecordNotFound if @concepts.blank?
      elsif (c_ids = permitted_params[:classification_ids] || permitted_params[:classificationIds]).present?
        @concepts = @concepts.where(id: c_ids.split(','))
      end

      @concepts = @concepts.includes(:concept_polygons) if helpers.included_attribute?('geo', @fields_parameters + @include_parameters)

      yield(@concepts) if block_given?

      @concepts = @concepts.with_locale(@language) if @language.present?
      @concepts = apply_ordering(@concepts)
      @concepts = apply_paging(@concepts)
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
                when DataCycleCore::Concept.const_get(:ActiveRecord_AssociationRelation), DataCycleCore::Concept.const_get(:ActiveRecord_Relation)
                  query.order(order_a: :asc, id: :asc)
                else
                  query.order(updated_at: :desc, id: :asc)
                end

        return query
      end

      query.reorder(nil).order(ActiveRecord::Base.send(:sanitize_sql_for_order, Arel.sql(order_query.join(', '))))
    end
  end
end
