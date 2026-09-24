# frozen_string_literal: true

module DataCycleCore
  # Renders the items of an embedded attribute into the edit form: a new item, records picked by id,
  # or a copy of an item as the form holds it (Feature::DuplicateEmbedded).
  module EmbeddedObjectRenderer
    extend ActiveSupport::Concern

    # Answers { html: } with the rendered items; a copy the validation rejects gets { error: } instead.
    def render_embedded_object
      @content = DataCycleCore::Thing.find_by(id: render_embedded_object_params[:id]) ||
                 content_by_id_or_template
      @key = render_embedded_object_params[:key]
      @definition = render_embedded_object_params[:definition]
      @index = render_embedded_object_params[:index]
      @options = render_embedded_object_params[:options]
      @locale = render_embedded_object_params[:locale]
      @attribute_locale = render_embedded_object_params[:attribute_locale]
      @duplicated_content = render_embedded_object_params[:duplicated_content]
      @hide_embedded = render_embedded_object_params[:hide_embedded]
      @translate = render_embedded_object_params[:translate]
      @embedded_template = render_embedded_object_params[:embedded_template]

      if @content&.persisted?
        authorize! :edit, @content
      else
        authorize! :edit, DataCycleCore::Thing
      end

      I18n.with_locale(@locale || I18n.locale) do
        return render_embedded_copy if render_embedded_object_params[:copy_data].present?

        @objects = DataCycleCore::Thing.includes(:translations).by_ordered_values(render_embedded_object_params[:object_ids]) if render_embedded_object_params[:object_ids].present?

        render json: { html: render_to_string(formats: [:html], layout: false).strip }
      end
    end

    private

    # A copy of an embedded as the form holds it, unsaved edits and unsaved items included: the
    # values are written to a transient record inside a transaction that is rolled back once the
    # HTML is rendered, so every editor renders from a record the way it always does. A copy the
    # validation rejects is answered with its errors, not with an empty item.
    def render_embedded_copy
      html = nil
      errors = []

      DataCycleCore::Thing.transaction do
        copy = DataCycleCore::DataHashService.create_internal_object(@embedded_template, embedded_copy_data, current_user, new_content: false)

        if copy.i18n_valid?
          @objects = [copy]
          @duplicated_content = true
          html = render_to_string(formats: [:html], layout: false)
        else
          errors = copy.i18n_errors.flat_map { |locale, e| e.full_messages.map { |m| "#{locale}: #{m}" } }
        end

        raise ActiveRecord::Rollback
      end

      return render(json: { error: errors.join(', ') }, status: :unprocessable_content) if html.nil?

      render json: { html: html.strip }
    end

    # the source's own id is what the copy must not carry; ids nested below stay, set_embedded links
    # what they name and _default decides per block whether the copy keeps the link
    def embedded_copy_data
      data = render_embedded_object_params[:copy_data].to_h
      data.delete('id')
      data['datahash']&.delete('id')
      data
    end

    def render_embedded_object_params
      params.permit(:id, :locale, :attribute_locale, :key, :index, :duplicated_content, :hide_embedded, :translate, :embedded_template, object_ids: [], definition: {}, options: {}, copy_data: {})
    end
  end
end
