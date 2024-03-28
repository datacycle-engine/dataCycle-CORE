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
            .order(:created_at)
            .distinct
        end

        format.json do
          @mapped_classification_aliases = DataCycleCore::ClassificationAlias.none.page(1)
          @classification_trees = DataCycleCore::ClassificationTree.none.page(1)
          @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find_by(id: index_params[:classification_tree_label_id])
          @type = index_params[:type]

          if index_params.include?(:mapped_classification_alias_id)
            @mapped_classification_alias = DataCycleCore::ClassificationAlias.find(index_params[:mapped_classification_alias_id])
            @mapped_classification_aliases = @mapped_classification_alias.additional_classifications.primary_classification_aliases
            @classification_trees = @mapped_classification_alias.sub_classification_alias
            @classification_type = @mapped_classification_alias
          elsif index_params.include?(:classification_tree_id)
            @classification_tree = DataCycleCore::ClassificationTree.find(index_params[:classification_tree_id])
            @classification_tree_label = @classification_tree.classification_tree_label
            @classification_trees = @classification_tree.sub_classification_alias.sub_classification_trees
            @mapped_classification_aliases = @classification_tree.sub_classification_alias&.additional_classifications&.primary_classification_aliases || DataCycleCore::ClassificationAlias.none.page(1)
            @classification_type = @classification_tree
            @queue_classification_mappings = Delayed::Job.where(
              delayed_reference_type: 'data_cycle_core_classification_alias_update_mappings',
              delayed_reference_id: @classification_trees.pluck(:classification_alias_id)
            ).pluck(:delayed_reference_id)
          elsif index_params.include?(:classification_tree_label_id)
            @classification_trees = @classification_tree_label.classification_trees.where(parent_classification_alias: nil)
            @classification_type = @classification_tree_label
            @queue_classification_mappings = Delayed::Job.where(
              delayed_reference_type: 'data_cycle_core_classification_alias_update_mappings',
              delayed_reference_id: @classification_trees.pluck(:classification_alias_id)
            ).pluck(:delayed_reference_id)
          else
            raise 'Missing parameter; either classification_tree_label_id or classification_tree_id must be provided'
          end

          authorize! :index, @classification_tree_label

          @mapped_classification_aliases = @mapped_classification_aliases
            .includes(:classification_alias_path, :classification_tree_label)
            .reorder(nil)
            .order('classification_tree_labels.name ASC, classification_aliases.order_a ASC').references(:classification_tree_labels)

          if @classification_type.is_a?(DataCycleCore::ClassificationAlias)
            @classification_trees = @classification_trees.includes(:classification_alias_path)
          else
            @classification_trees = @classification_trees
            .joins(:sub_classification_alias)
            .includes(
              sub_classification_alias: [
                :classification_alias_path,
                :classification_tree_label,
                additional_classifications: [primary_classification_alias: :classification_alias_path],
                primary_classification: [additional_classification_aliases: :classification_alias_path],
                classifications: [primary_classification_alias: :classification_alias_path]
              ]
            )

            @classification_polygon_counts = @classification_trees
              .joins(sub_classification_alias: :classification_polygons)
              .group(:classification_alias_id)
              .count
          end

          @classification_trees = @classification_trees.order('classification_aliases.order_a ASC')

          render json: { html: render_to_string(formats: [:html], layout: false, action: 'children').strip }
        end
      end
    end

    def search
      query = if search_params[:tree_label].present? && search_params[:tree_label] == 'Inhaltstypen'
                DataCycleCore::ClassificationAlias.for_tree(search_params[:tree_label]).where.not(name: DataCycleCore.excluded_filter_classifications)
              elsif search_params[:tree_label].present?
                DataCycleCore::ClassificationAlias.for_tree(search_params[:tree_label])
              else
                DataCycleCore::ClassificationAlias.all
              end

      I18n.with_locale(helpers.active_ui_locale) do
        query = query.search(search_params[:q])
      end
      query = query.order_by_similarity(search_params[:q])
      query = query.limit(search_params[:max].try(:to_i) || DEFAULT_CLASSIFICATION_SEARCH_LIMIT)
      query = query.where.not(id: search_params[:exclude]) if search_params[:exclude].present?
      if search_params[:exclude_tree_label].present?
        query = query.includes(:classification_tree)
          .where.not(classification_trees: { classification_tree_label_id: search_params[:exclude_tree_label] })
      end
      query = query.preload(*Array.wrap(search_params[:preload])) if search_params[:preload].present?
      query = query.preload(:primary_classification, :classification_alias_path)

      render plain: query.map { |a|
        next if a.primary_classification.nil?

        {
          classification_id: a.primary_classification.id,
          classification_alias_id: a.id,
          name: a.internal_name,
          full_path: a.full_path,
          dc_tooltip: helpers.classification_tooltip(a),
          disabled: search_params[:disabled_unless_any?].present? ? a.try(search_params[:disabled_unless_any?]).none? : !a.assignable
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
      if create_params[:classification_tree_label]
        @object = DataCycleCore::ClassificationTreeLabel.create!(create_params[:classification_tree_label])
      else
        @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find(create_params[:classification_tree_label_id])

        if create_params['classification_tree_id']
          @classification_tree = DataCycleCore::ClassificationTree.find(create_params['classification_tree_id'])
        else
          @classification_tree = nil
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
            parent_classification_alias: @classification_tree.try(:sub_classification_alias),
            sub_classification_alias: @classification_alias
          })
        end
      end

      render json: { html: render_to_string(formats: [:html], layout: false, action: 'create').strip }
    rescue ActiveRecord::RecordInvalid
      render json: { error: I18n.with_locale(helpers.active_ui_locale) { @classification_alias.errors.full_messages.join(', ') } }
    end

    def update
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

        if update_params[:classification_alias]&.key?(:classification_ids)
          classification_ids = Array.wrap(update_params[:classification_alias].delete('classification_ids'))

          if classification_ids.sort != @object.classification_ids&.sort
            DataCycleCore::ClassificationMappingJob.perform_later(@object.id, classification_ids - @object.classification_ids, @object.classification_ids - classification_ids)
            flash[:success] = I18n.t('controllers.success.classification_mappings_queued', locale: helpers.active_ui_locale)
          end
        end

        @object.attributes = update_params[:classification_alias].except(:translation)
        @object.save!
      end

      render json: { html: render_to_string(formats: [:html], layout: false, action: 'update', locals: { :@queue_classification_mappings => Delayed::Job.exists?(delayed_reference_type: 'data_cycle_core_classification_alias_update_mappings', delayed_reference_id: @object.id) ? [@object.id] : [] }).strip }.merge(flash.discard.to_h)
    rescue ActiveRecord::RecordInvalid
      render json: { error: I18n.with_locale(helpers.active_ui_locale) { @object.errors.full_messages.join(', ') } }
    end

    def destroy
      if destroy_params.include?(:classification_tree_label_id)
        @object = DataCycleCore::ClassificationTreeLabel.find(params[:classification_tree_label_id])
      elsif destroy_params.include?(:classification_tree_id)
        @object = DataCycleCore::ClassificationTree.find(params[:classification_tree_id])
      else
        raise 'Missing parameter; either classification_tree_label_id or classification_tree_id must be provided'
      end

      authorize! :destroy, @object

      @object.destroy

      render json: { deleted: true }
    end

    def download
      object = DataCycleCore::ClassificationTreeLabel.find(download_params[:classification_tree_label_id])

      respond_to do |format|
        format.csv do
          if download_params[:include_contents]
            raw_csv = object.to_csv(include_contents: true)
          elsif download_params[:specific_type] == 'mapping_import'
            raw_csv = object.to_csv_for_mappings
          elsif download_params[:specific_type] == 'mapping_export'
            raw_csv = object.to_csv_with_mappings
          elsif download_params[:specific_type] == 'mapping_export_inverse'
            raw_csv = object.to_csv_with_inverse_mappings
          else
            raw_csv = object.to_csv
          end

          send_data "sep=,\n" + raw_csv.encode('ISO-8859-1', invalid: :replace, undef: :replace),
                    type: 'text/csv; charset=iso-8859-1;',
                    filename: "#{object.name}.csv"
        end
      end
    end

    def move
      classification_tree_label = DataCycleCore::ClassificationTreeLabel.find(move_params[:classification_tree_label_id])

      authorize! :edit, classification_tree_label

      raise ActiveRecord::RecordNotFound if move_params[:classification_alias_id].blank?

      aliases = DataCycleCore::ClassificationAlias.where(id: move_params.values_at(:classification_alias_id, :previous_alias_id, :new_parent_alias_id).compact).index_by(&:id)

      aliases[move_params[:classification_alias_id]].move_after(
        classification_tree_label,
        move_params[:previous_alias_id]&.then { |pca| aliases[pca] },
        move_params[:new_parent_alias_id]&.then { |npca| aliases[npca] }
      )

      flash.now[:success] = I18n.t('classification_administration.move.success', locale: helpers.active_ui_locale)

      render json: flash.discard.to_h
    end

    def merge
      aliases = DataCycleCore::ClassificationAlias.where(id: merge_params.values_at(:source_alias_id, :target_alias_id).compact).index_by(&:id)
      source_alias = aliases[merge_params[:source_alias_id]]
      target_alias = aliases[merge_params[:target_alias_id]]

      raise ActiveRecord::RecordNotFound if source_alias.nil? || target_alias.nil?
      authorize! :edit, source_alias
      authorize! :edit, target_alias

      source_alias.merge_with_children(target_alias)

      flash.now[:success] = I18n.t('classification_administration.merge.success', locale: helpers.active_ui_locale)

      render json: flash.discard.to_h
    end

    private

    def download_params
      params.permit(:classification_tree_label_id, :include_contents, :specific_type)
    end

    def search_params
      params.permit(:q, :max, :tree_label, :exclude, :exclude_tree_label, :disabled_unless_any?, :preload, preload: [])
    end

    def move_params
      params.transform_keys(&:underscore).permit(:classification_alias_id, :classification_tree_label_id, :previous_alias_id, :new_parent_alias_id)
    end

    def merge_params
      params.transform_keys(&:underscore).permit(:source_alias_id, :target_alias_id)
    end

    def destroy_params
      params.permit(:classification_tree_label_id, :classification_tree_id)
    end

    def index_params
      params.permit(:classification_tree_label_id, :classification_tree_id, :mapped_classification_alias_id, :type)
    end

    def create_params
      return @create_params if defined? @create_params
      @create_params = begin
        params.dig(:classification_tree_label, :visibility)&.delete_if(&:blank?)
        params.dig(:classification_tree_label, :change_behaviour)&.delete_if(&:blank?)

        normalize_names(params).permit(
          :classification_tree_label_id,
          :classification_tree_id,
          classification_tree_label: [:id, :name, :internal, visibility: [], change_behaviour: []],
          classification_alias: [:id, :name, :internal, :uri, :assignable, :description, translation: locale_params, classification_ids: [], ui_configs: [:color]]
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
          classification_alias: [:id, :name, :internal, :uri, :assignable, :description, translation: locale_params, classification_ids: [], ui_configs: [:color]]
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
          v.compact_blank!.flatten.each { |x| normalize_names(x) if x.is_a?(Hash) }
        elsif k.to_s == 'name'
          v.squish!
        end
      end
      hash
    end
  end
end
