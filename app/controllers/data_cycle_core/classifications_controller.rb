# frozen_string_literal: true

module DataCycleCore
  class ClassificationsController < ApplicationController
    DEFAULT_CLASSIFICATION_SEARCH_LIMIT = 128
    UNLINK_PARAMS_SCHEMA = DataCycleCore::BaseSchema.params do
      required(:concept_scheme_link).hash do
        required(:id).filled(:uuid?)
        required(:collection_id).filled(:uuid?)
      end
    end

    # #50677: params scope => attribute => the ability its form field is rendered under, enforced by
    # without_unpermitted_gated_attributes. Keep in sync with _concept_scheme_form and _concept_form.
    # ui_configs is dropped whole because :color is the only sub-key permitted and it is the gated one;
    # a second one would need this to map sub-keys instead.
    GATED_ATTRIBUTES = {
      concept_scheme: {
        internal: :update_internal,
        mappable: :update_mappable,
        hidden_mappings: :update_hidden_mappings,
        change_behaviour: :update_change_behaviour
      },
      concept: {
        internal: :update_internal,
        ui_configs: :set_color
      }
    }.freeze

    def index
      respond_to do |format|
        format.html do
          authorize! :index, DataCycleCore::ConceptScheme

          @concept_schemes = DataCycleCore::ConceptScheme
            .accessible_by(current_ability)
            .order(:created_at)
            .distinct
        end

        format.json do
          @mapped_concepts = DataCycleCore::Concept.none.page(1)
          @concepts = DataCycleCore::Concept.none.page(1)
          @concept_scheme = DataCycleCore::ConceptScheme.find_by(id: index_params[:concept_scheme_id])
          @type = index_params[:type]

          # A mapped concept belongs to another scheme, so its subtree is only browsable, never
          # administrable - which is what the view renders differently, and it keeps the scheme
          # being administered rather than adopting the mapped concept's own.
          @mapped_view = index_params.include?(:mapped_concept_id)

          if @mapped_view || index_params.include?(:concept_id)
            @concept = DataCycleCore::Concept.find(index_params[:mapped_concept_id] || index_params[:concept_id])
            @concept_scheme = @concept.concept_scheme unless @mapped_view
            @concepts = @concept.children
            @mapped_concepts = @concept.mapped_concepts
          elsif index_params.include?(:concept_scheme_id)
            @concepts = @concept_scheme.concepts.roots
          else
            raise 'Missing parameter; either concept_scheme_id or concept_id must be provided'
          end

          authorize! :index, @concept_scheme

          @mapped_concepts = @mapped_concepts
            .includes(:concept_path, :concept_scheme)
            .reorder(nil)
            .order('concept_schemes.name ASC, concepts.order_a ASC').references(:concept_scheme)

          unless @mapped_view
            @concept_polygon_counts = @concepts.reorder(nil).joins(:concept_polygons).group(:id).count
            @queued_concept_mappings = queued_concept_mappings(@concepts.pluck(:id))
          end

          @concepts = @concepts.includes(:concept_path, :concept_scheme, :external_system, children: :concept_path,
                                                                                           mapped_concepts: :concept_path, mapped_inverse_concepts: :concept_path)

          render json: { html: render_to_string(formats: [:html], layout: false, action: 'children').strip }
        end
      end
    end

    def search
      query = if search_params[:tree_label].present? && search_params[:tree_label] == 'Inhaltstypen'
                DataCycleCore::Concept.for_tree(search_params[:tree_label]).where.not(name: DataCycleCore.excluded_filter_classifications)
              elsif search_params[:tree_label].present?
                DataCycleCore::Concept.for_tree(search_params[:tree_label])
              else
                DataCycleCore::Concept.all
              end

      matches = nil
      if search_params[:q].present?
        I18n.with_locale(helpers.active_ui_locale) do
          query = query.search(search_params[:q])
          matches = search_params[:q].squish.split(/\s/)
        end
        query = query.order_by_similarity(search_params[:q])
      end
      query = query.assignable
      query = query.limit(search_params[:max].try(:to_i) || DEFAULT_CLASSIFICATION_SEARCH_LIMIT)
      query = query.where.not(id: search_params[:exclude]) if search_params[:exclude].present?
      query = query.where.not(concept_scheme_id: search_params[:exclude_tree_label]) if search_params[:exclude_tree_label].present?
      query = query.where(DataCycleCore::ConceptPolygon.where('concept_polygons.concept_id = concepts.id').select(1).arel.exists) if search_params[:with_geometry].to_s == 'true'
      query = query.preload(*Array.wrap(search_params[:preload])) if search_params[:preload].present?
      query = query.preload(:concept_path)

      render plain: query.map { |c| to_select_json(c, matched_name: helpers.matched_concept_path(c.full_path, matches), disabled_unless_any: search_params[:disabled_unless_any?]) }.to_json,
             content_type: 'application/json'
    end

    def find
      query = DataCycleCore::Concept.where(id: find_params[:ids]).preload(:concept_path)
      query = query.for_tree(find_params[:tree_label]) if find_params[:tree_label].present?

      render plain: query.map { |c| to_select_json(c) }.to_json, content_type: 'application/json'
    end

    def create
      if create_params[:concept_scheme]
        @object = DataCycleCore::ConceptScheme.new(create_params[:concept_scheme])
      else
        @concept_scheme = DataCycleCore::ConceptScheme.find(create_params[:concept_scheme_id])
        @parent_concept = DataCycleCore::Concept.find(create_params[:parent_concept_id]) if create_params[:parent_concept_id].present?

        # the `broader` link to @parent_concept is written by Concept's after_create callback
        @object = DataCycleCore::Concept.new(create_params[:concept].except(:translation))
        @object.concept_scheme = @concept_scheme
        @object.parent_concept = @parent_concept

        create_params.dig(:concept, :translation).presence&.each do |locale, values|
          I18n.with_locale(locale.to_sym) do
            @object.attributes = values
          end
        end
      end

      @object.save!

      render json: { html: render_to_string(formats: [:html], layout: false, action: 'create').strip }
    rescue ActiveRecord::RecordInvalid
      render json: { error: I18n.with_locale(helpers.active_ui_locale) { @object.errors.full_messages.join(', ') } }
    end

    def update
      if update_params[:concept_scheme]
        @object = DataCycleCore::ConceptScheme.find(update_params[:concept_scheme][:id])
        @object.update!(update_params[:concept_scheme])
      else
        @object = DataCycleCore::Concept.find(update_params[:concept][:id])

        update_params.dig(:concept, :translation).presence&.each do |locale, values|
          I18n.with_locale(locale.to_sym) do
            @object.attributes = values
          end
        end

        if update_params[:concept]&.key?(:mapped_concept_ids)
          mapped_concept_ids = Array.wrap(update_params[:concept].delete('mapped_concept_ids'))

          if mapped_concept_ids.sort != @object.mapped_concept_ids.sort && @object.concept_scheme.mappable
            DataCycleCore::ClassificationMappingJob.perform_later(@object.id, mapped_concept_ids - @object.mapped_concept_ids, @object.mapped_concept_ids - mapped_concept_ids)
            flash[:success] = I18n.t('controllers.success.classification_mappings_queued', locale: helpers.active_ui_locale)
          end
        end

        @object.attributes = update_params[:concept].except(:translation)
        @object.save!
      end

      render json: {
        html: render_to_string(
          formats: [:html],
          layout: false,
          action: 'update',
          assigns: {
            queued_concept_mappings: queued_concept_mappings([@object.id])
          }
        ).strip
      }.merge(flash.discard.to_h)
    rescue ActiveRecord::RecordInvalid
      render json: { error: I18n.with_locale(helpers.active_ui_locale) { @object.errors.full_messages.join(', ') } }
    end

    # Renders the "used in stored filters" panel for a concept or concept_scheme, shown via a
    # lazily-loaded turbo frame from the classification admin's overflow menu.
    def stored_filter_usage
      authorize! :index, DataCycleCore::StoredFilter

      @classification_id = stored_filter_usage_params[:id]
      usage = DataCycleCore::StoredFilter.used_by_classification(@classification_id)

      # The count itself stays global (deleting a concept affects every user's saved
      # searches), but listing names/links must not leak stored filters the current user cannot
      # open - same scope as StoredFiltersController#saved_searches, which the links point to.
      accessible_ids = DataCycleCore::StoredFilter.accessible_by(current_ability).where(id: usage.keys.map(&:id)).ids.to_set
      @stored_filter_usage = usage.select { |filter, _direct| accessible_ids.include?(filter.id) }
      @hidden_usage_count = usage.size - @stored_filter_usage.size

      render 'data_cycle_core/classifications/stored_filter_usage', layout: false
    end

    def destroy
      if destroy_params.include?(:concept_scheme_id)
        @object = DataCycleCore::ConceptScheme.find(destroy_params[:concept_scheme_id])
      elsif destroy_params.include?(:concept_id)
        @object = DataCycleCore::Concept.find(destroy_params[:concept_id])
      else
        raise 'Missing parameter; either concept_scheme_id or concept_id must be provided'
      end

      authorize! :destroy, @object

      @object.destroy

      render json: { deleted: true }
    end

    def download
      object = DataCycleCore::ConceptScheme.find(download_params[:concept_scheme_id])

      respond_to do |format|
        format.csv do
          raw_csv = if download_params[:include_contents]
                      object.to_csv(include_contents: true)
                    elsif download_params[:specific_type] == 'mapping_import'
                      object.to_csv_for_mappings
                    elsif download_params[:specific_type] == 'mapping_export'
                      object.to_csv_with_mappings
                    elsif download_params[:specific_type] == 'mapping_export_inverse'
                      object.to_csv_with_inverse_mappings
                    else
                      object.to_csv
                    end

          send_data "sep=,\n#{raw_csv.encode('ISO-8859-1', invalid: :replace, undef: :replace)}",
                    type: 'text/csv; charset=iso-8859-1;',
                    filename: "#{object.name}.csv"
        end
      end
    end

    def move
      concept_scheme = DataCycleCore::ConceptScheme.find(move_params[:concept_scheme_id])

      authorize! :edit, concept_scheme

      raise ActiveRecord::RecordNotFound if move_params[:concept_id].blank?

      concepts = DataCycleCore::Concept.where(id: move_params.values_at(:concept_id, :previous_concept_id, :new_parent_concept_id).compact).index_by(&:id)

      concepts[move_params[:concept_id]].move_after(
        concept_scheme,
        move_params[:previous_concept_id]&.then { |id| concepts[id] },
        move_params[:new_parent_concept_id]&.then { |id| concepts[id] }
      )

      flash.now[:success] = I18n.t('classification_administration.move.success', locale: helpers.active_ui_locale)

      render json: flash.discard.to_h
    end

    def merge
      concepts = DataCycleCore::Concept.where(id: merge_params.values_at(:source_concept_id, :target_concept_id).compact).index_by(&:id)
      source_concept = concepts[merge_params[:source_concept_id]]
      target_concept = concepts[merge_params[:target_concept_id]]

      raise ActiveRecord::RecordNotFound if source_concept.nil? || target_concept.nil?

      authorize! :edit, source_concept
      authorize! :edit, target_concept

      source_concept.merge_with_children(target_concept)

      flash.now[:success] = I18n.t('classification_administration.merge.success', locale: helpers.active_ui_locale)

      render json: flash.discard.to_h
    rescue DataCycleCore::Error::AmbiguousConceptExternalSystemError
      render json: { error: I18n.t('classification_administration.merge.ambiguous_external_system', locale: helpers.active_ui_locale) }
    end

    def unlink_contents
      collection = DataCycleCore::Collection.find(link_params[:collection_id])
      concept_scheme = DataCycleCore::ConceptScheme.find(link_params[:id])

      authorize! :unlink_contents, concept_scheme

      DataCycleCore::ConceptSchemeUnlinkJob.perform_later(concept_scheme.id, collection.id, current_user.id)

      render json: flash.discard.to_h
    end

    def link_contents
      collection = DataCycleCore::Collection.find(link_params[:collection_id])
      concept_scheme = DataCycleCore::ConceptScheme.find(link_params[:id])

      authorize! :link_contents, concept_scheme

      DataCycleCore::ConceptSchemeLinkJob.perform_later(concept_scheme.id, collection.id, current_user.id)

      render json: flash.discard.to_h
    end

    # Usage: backs the geographic content editor's "shape from concept" overlay
    # (views/.../contents/editors/geographic/_shape_from_concept_overlay). That form posts the selected
    # concept ids (concepts[]) to geometry_classifications_path; this returns the
    # combined ConceptPolygon GeoJSON, rendered into the "<id>-geometry" turbo frame, so an editor
    # can set a content's geometry from concept boundaries (e.g. region/municipality/protected-area shapes)
    # instead of drawing it by hand. Backend-only via authorize! :index, :backend (DC-24).
    def geometry
      authorize! :index, :backend

      geojson = DataCycleCore::ConceptPolygon
        .where(concept_id: geometry_params[:concepts])
        .combined_geojson

      respond_to do |format|
        format.json { render json: geojson }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "#{geometry_params[:id]}-geometry",
            html: helpers.turbo_frame_tag("#{geometry_params[:id]}-geometry", data: { geojson: }),
            method: :morph
          )
        end
      end
    end

    private

    # One concept as the async select2 endpoints deliver it. Both endpoints answer the same shape,
    # and the id is the concept's own - the Classification/ClassificationAlias pair the client used
    # to choose between (`data-alias-ids`) is one record now.
    def to_select_json(concept, matched_name: nil, disabled_unless_any: nil)
      {
        id: concept.id,
        name: concept.internal_name,
        matched_name:,
        full_path: concept.full_path,
        dc_tooltip: helpers.concept_tooltip(concept),
        disabled: disabled_unless_any.present? ? concept.try(disabled_unless_any).none? : !concept.assignable
      }.compact
    end

    # Which of the given concepts still have a mapping job outstanding, so the view can
    # show them as queued. The key is asked of the job class instead of being spelled out here: it is
    # SolidQueue's +[group, param]+ join, and adding a +group:+ to +limits_concurrency+ would
    # otherwise silently turn this into an empty result rather than an error.
    # @param concept_ids [Array<String>]
    # @return [Array<String>] the subset that is queued or running
    def queued_concept_mappings(concept_ids)
      keys = concept_ids.index_by { |id| DataCycleCore::ClassificationMappingJob.new(id).concurrency_key }

      SolidQueue::Job.live.where(concurrency_key: keys.keys).pluck(:concurrency_key).filter_map { |key| keys[key] }
    end

    def geometry_params
      params.permit(:id, concepts: [])
    end

    def download_params
      params.permit(:concept_scheme_id, :include_contents, :specific_type)
    end

    def search_params
      params.permit(:q, :max, :tree_label, :exclude, :exclude_tree_label, :disabled_unless_any?, :with_geometry, :preload, preload: [])
    end

    def move_params
      params.transform_keys(&:underscore).permit(:concept_id, :concept_scheme_id, :previous_concept_id, :new_parent_concept_id)
    end

    def merge_params
      params.transform_keys(&:underscore).permit(:source_concept_id, :target_concept_id)
    end

    def destroy_params
      params.permit(:concept_scheme_id, :concept_id)
    end

    def index_params
      params.permit(:concept_scheme_id, :concept_id, :mapped_concept_id, :type)
    end

    def create_params
      return @create_params if defined? @create_params

      @create_params = begin
        params.dig(:concept_scheme, :visibility)&.delete_if(&:blank?)
        params.dig(:concept_scheme, :change_behaviour)&.delete_if(&:blank?)

        without_unpermitted_gated_attributes(
          normalize_names(params).permit(
            :concept_scheme_id,
            :parent_concept_id,
            concept_scheme: [:id, :name, :internal, :mappable, :hidden_mappings, { visibility: [], change_behaviour: [] }],
            concept: [:id, :name, :internal, :uri, :assignable, :description, { translation: locale_params, mapped_concept_ids: [], ui_configs: [:color] }]
          )
        )
      end
    end

    def update_params
      return @update_params if defined? @update_params

      @update_params = begin
        params.dig(:concept_scheme, :visibility)&.delete_if(&:blank?)
        params.dig(:concept_scheme, :change_behaviour)&.delete_if(&:blank?)

        without_unpermitted_gated_attributes(
          normalize_names(params).permit(
            concept_scheme: [:id, :name, :internal, :mappable, :hidden_mappings, { visibility: [], change_behaviour: [] }],
            concept: [:id, :name, :internal, :uri, :assignable, :description, { translation: locale_params, mapped_concept_ids: [], ui_configs: [:color] }]
          )
        )
      end
    end

    # #50677: attributes whose form field is gated on an ability of its own — the concept scheme form and
    # the concept form only render them for holders of the mapped action. create/update
    # authorize nothing beyond this, so dropping the parameters here is what makes those gates hold for a
    # hand-crafted request too.
    def without_unpermitted_gated_attributes(permitted)
      GATED_ATTRIBUTES.each do |scope, gates|
        attributes = permitted[scope]
        next if attributes.blank?

        submitted = gates.slice(*attributes.keys.map(&:to_sym))
        next if submitted.blank?

        subject = gated_subject(scope, attributes[:id])
        denied = submitted.filter_map { |attribute, action| attribute if cannot?(action, subject) }

        permitted[scope] = attributes.except(*denied) if denied.present?
      end

      permitted
    end

    # the persisted record where there is one (the SubjectNotExternal-style segments of these abilities
    # only exclude external/internal subjects on an instance), the class on create
    def gated_subject(scope, id)
      model = case scope
              when :concept_scheme then DataCycleCore::ConceptScheme
              when :concept then DataCycleCore::Concept
              end

      model.find_by(id:) || model
    end

    def find_params
      return @find_params if defined? @find_params

      @find_params = params.permit(:tree_label, ids: [])
    end

    def stored_filter_usage_params
      params.permit(:id)
    end

    def locale_params
      I18n.available_locales.map { |l| [{ l.to_sym => [:name, :description] }] }
    end

    def normalize_names(hash)
      hash.each do |k, v|
        if v.is_a?(Hash) || v.is_a?(ActionController::Parameters)
          normalize_names v
        elsif v.is_a?(Array)
          v.compact_blank!.flatten.each { |x| normalize_names(x) if x.is_a?(Hash) }
        elsif k.to_s.in?(['name', 'description']) && v.is_a?(String)
          hash[k] = v.squish.presence
        end
      end

      hash
    end

    def link_params
      params_for(UNLINK_PARAMS_SCHEMA)&.dig(:concept_scheme_link)
    end
  end
end
