# frozen_string_literal: true

module DataCycleCore
  class ClassificationsController < ApplicationController
    FIXNUM_MAX = (2**(0.size * 8 - 2) - 1)

    DEFAULT_CLASSIFICATION_SEARCH_LIMIT = 128

    def index
      respond_to do |format|
        format.html do
          authorize! :index, DataCycleCore::ClassificationTreeLabel

          @classification_tree_labels = DataCycleCore::ClassificationTreeLabel
            .accessible_by(current_ability)
            .includes(:statistics)
            .order(:created_at)
            .distinct
        end

        format.js do
          authorize! :index, DataCycleCore::ClassificationTree

          permitted_params = params.permit(:classification_tree_label_id, :classification_tree_id)

          if permitted_params.include?(:classification_tree_label_id)
            @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find(params[:classification_tree_label_id])
            @classification_trees = @classification_tree_label.classification_trees.where(parent_classification_alias: nil)

          elsif permitted_params.include?(:classification_tree_id)
            @classification_tree = DataCycleCore::ClassificationTree.find(params[:classification_tree_id])
            @classification_tree_label = @classification_tree.classification_tree_label
            @classification_trees = @classification_tree.sub_classification_alias.sub_classification_trees
          else
            raise 'Missing parameter; either classification_tree_label_id or classification_tree_id must be provided'
          end

          @classification_trees = @classification_trees
            .accessible_by(current_ability)
            .joins(:sub_classification_alias)
            .includes(
              sub_classification_alias: {
                classifications: { primary_classification_alias: :classification_alias_path },
                primary_classification: {},
                additional_classifications: {},
                statistics: {}
              }
            ).order('classification_aliases.internal_name')
            .page(params[:page])

          @page = @classification_trees.current_page

          @total_pages = @classification_trees.total_pages
        end
      end
    end

    def search
      params.permit(:q, :max, :tree_label, :exclude)

      query = if params[:tree_label].present? && params[:tree_label] == 'Inhaltstypen'
                DataCycleCore::ClassificationAlias.for_tree(params[:tree_label]).where.not(name: DataCycleCore.excluded_filter_classifications)
              elsif params[:tree_label].present?
                DataCycleCore::ClassificationAlias.for_tree(params[:tree_label])
              else
                DataCycleCore::ClassificationAlias.all
              end

      I18n.with_locale(helpers.active_ui_locale) do
        query = query.search(params[:q])
      end
      query = query.order_by_similarity(params[:q])
      query = query.limit(params[:max].try(:to_i) || DEFAULT_CLASSIFICATION_SEARCH_LIMIT)
      query = query.where.not(id: params[:exclude]) if params[:exclude].present?
      query = query.preload(:primary_classification, :classification_alias_path)

      render plain: query.map { |a|
        next if a.primary_classification.nil?

        {
          classification_id: a.primary_classification.id,
          classification_alias_id: a.id,
          name: a.internal_name,
          full_path: a.full_path,
          dc_tooltip: helpers.classification_tooltip(a),
          disabled: !a.assignable
        }
      }.compact.to_json, content_type: 'application/json'
    end

    def find
      query = DataCycleCore::Classification.where(id: find_params[:ids]).preload(primary_classification_alias: :classification_alias_path)
      query = query.for_tree(find_params[:tree_label]) if find_params[:tree_label].present?

      render plain: query.map { |c|
        next if c.primary_classification_alias.nil?

        {
          classification_id: c.id,
          classification_alias_id: c.primary_classification_alias.id,
          name: c.primary_classification_alias.internal_name,
          full_path: c.primary_classification_alias.full_path,
          dc_tooltip: helpers.classification_tooltip(c.primary_classification_alias),
          disabled: !c.primary_classification_alias.assignable
        }
      }.compact.to_json, content_type: 'application/json'
    end

    def create
      respond_to do |format|
        format.html do
          raise NotImplemented
        end

        format.js do
          if create_params[:classification_tree_label]
            @object = DataCycleCore::ClassificationTreeLabel.create!(create_params[:classification_tree_label])
          else
            @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find(create_params[:classification_tree_label_id])

            if create_params['classification_tree_id']
              @parent_classification_tree = DataCycleCore::ClassificationTree.find(create_params['classification_tree_id'])
            else
              @parent_classification_tree = nil
            end

            ActiveRecord::Base.transaction do
              @classification_alias = DataCycleCore::ClassificationAlias.new(create_params[:classification_alias].except(:translation))
              create_params.dig(:classification_alias, :translation).presence&.each do |locale, values|
                I18n.with_locale(locale.to_sym) do
                  @classification_alias.attributes = values
                end
              end
              @classification_alias.save!
              @classification = DataCycleCore::Classification.create!(name: @classification_alias.internal_name)
              @classification_group = DataCycleCore::ClassificationGroup.create!(
                classification: @classification,
                classification_alias: @classification_alias
              )
              @object = DataCycleCore::ClassificationTree.create!({
                classification_tree_label: @classification_tree_label,
                parent_classification_alias: @parent_classification_tree.try(:sub_classification_alias),
                sub_classification_alias: @classification_alias
              })
            end
          end
        end
      end
    end

    def update
      respond_to do |format|
        format.html do
          raise NotImplemented
        end

        format.js do
          if update_params[:classification_tree_label]
            @object = DataCycleCore::ClassificationTreeLabel.find(update_params[:classification_tree_label][:id])
            @object.update!(update_params[:classification_tree_label])
          else
            @object = DataCycleCore::ClassificationAlias.find(update_params[:classification_alias][:id])

            update_params.dig(:classification_alias, :translation).presence&.each do |locale, values|
              I18n.with_locale(locale.to_sym) do
                @object.attributes = values
              end
            end

            @object.attributes = update_params[:classification_alias].except(:translation)
            @object.save!
          end
        end
      end
    end

    def destroy
      permitted_params = params.permit(:classification_tree_label_id, :classification_tree_id)

      respond_to do |format|
        format.html do
          raise NotImplemented
        end

        format.js do
          if permitted_params.include?(:classification_tree_label_id)
            @object = DataCycleCore::ClassificationTreeLabel.find(params[:classification_tree_label_id])
          elsif permitted_params.include?(:classification_tree_id)
            @object = DataCycleCore::ClassificationTree.find(params[:classification_tree_id])
          else
            raise 'Missing parameter; either classification_tree_label_id or classification_tree_id must be provided'
          end

          authorize! :destroy, @object

          @object.destroy
        end
      end
    end

    def download
      params.permit(:classification_tree_label_id, :include_contents, :for_mapping_import)

      object = DataCycleCore::ClassificationTreeLabel.find(params[:classification_tree_label_id])

      respond_to do |format|
        format.csv do
          if params[:include_contents]
            raw_csv = object.to_csv(include_contents: true)
          elsif params[:for_mapping_import]
            raw_csv = object.to_csv_for_mappings
          else
            raw_csv = object.to_csv
          end

          send_data "sep=,\n" + raw_csv.encode('ISO-8859-1', invalid: :replace, undef: :replace),
                    type: 'text/csv; charset=iso-8859-1;',
                    filename: "#{object.name}.csv"
        end
      end
    end

    private

    def create_params
      return @create_params if defined? @create_params
      @create_params = begin
        params.dig(:classification_tree_label, :visibility)&.delete_if(&:blank?)
        params.dig(:classification_tree_label, :change_behaviour)&.delete_if(&:blank?)

        normalize_names(params).permit(
          :classification_tree_label_id,
          :classification_tree_id,
          classification_tree_label: [:id, :name, :internal, visibility: [], change_behaviour: []],
          classification_alias: [:id, :name, :internal, :assignable, :description, translation: locale_params, classification_ids: []]
        )
      end
    end

    def update_params
      return @update_params if defined? @update_params
      @update_params = begin
        params.dig(:classification_tree_label, :visibility)&.delete_if(&:blank?)
        params.dig(:classification_tree_label, :change_behaviour)&.delete_if(&:blank?)

        normalize_names(params).permit(
          classification_tree_label: [:id, :name, :internal, visibility: [], change_behaviour: []],
          classification_alias: [:id, :name, :internal, :assignable, :description, translation: locale_params, classification_ids: []]
        )
      end
    end

    def find_params
      return @find_params if defined? @find_params

      @find_params = params.permit(:tree_label, ids: [])
    end

    def locale_params
      I18n.available_locales.map { |l| [l.to_sym => [:name, :description]] }
    end

    def normalize_names(hash)
      hash.each do |k, v|
        if v.is_a?(Hash) || v.is_a?(ActionController::Parameters)
          normalize_names v
        elsif v.is_a?(Array)
          v.flatten.each { |x| normalize_names(x) if x.is_a?(Hash) }
        elsif k.to_s == 'name'
          v.squish!
        end
      end
      hash
    end
  end
end
