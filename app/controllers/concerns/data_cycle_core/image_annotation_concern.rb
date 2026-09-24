# frozen_string_literal: true

module DataCycleCore
  # Shared plumbing of the two image annotation endpoints (AnnotationPixie's focus point,
  # ImageDescriptionPixie's texts). Both answer for either a persisted content (+thing_id+) or an
  # image that has only been uploaded so far (+asset_id+ plus +template_name+, the upload mask), and
  # both read from the same annotation.
  #
  # It lives here rather than under feature/controller_functions/ because no feature returns it from
  # #controller_module: what it holds is the request handling two features share, and everything
  # about an image that is not request handling is on Feature::Concerns::ImageContent and the two
  # feature classes.
  module ImageAnnotationConcern
    extend ActiveSupport::Concern

    private

    # Runs the guards both endpoints share and yields the annotation to the block that turns it
    # into the endpoint's answer.
    #
    # The image URL is always derived from the asset server-side -- a client-supplied URL would
    # turn either endpoint into a fetch proxy for the annotation service.
    #
    # An image annotated once keeps that answer on its embedding row, so a wand on a backfilled
    # image is answered without asking the service at all. Whether the stored one *can* answer
    # differs per endpoint, and the block decides it by what it extracts: a stored annotation is
    # used only when the payload it yields carries a value, so a row holding a focus point but no
    # English alt text still sends the texts endpoint to the service. A payload built from a
    # fresh annotation is rendered either way -- "the service found no focus point" is an answer,
    # and +{ focus_point: nil }+ is how it is delivered.
    #
    # @param feature [Class] the pixie whose availability gates this request
    # @yieldparam data [Hash] the annotations of the image
    # @yieldparam content [DataCycleCore::Thing] the content it was requested for
    # @yieldreturn [Hash] the response body
    def with_image_annotation(feature)
      content = image_annotation_content
      raise ActiveRecord::RecordNotFound if content.blank?
      raise CanCan::AccessDenied unless feature.allowed?(content)

      asset = image_annotation_asset(content)
      authorize_image_annotation!(content, asset)

      embedding = DataCycleCore::Feature['Embedding']
      return render_image_annotation_error(I18n.t('controllers.error.feature_not_enabled', locale: helpers.active_ui_locale)) if embedding.blank?

      stored = embedding.try(:stored_annotation, content)
      if stored.is_a?(::Hash)
        answer = yield(stored, content)
        return render json: answer if image_annotation_answered?(answer)
      end

      image_url = feature.image_url(content, asset)
      return render_image_annotation_error(I18n.t('validation.warnings.no_data', data: 'Bild', locale: helpers.active_ui_locale)) if image_url.blank?

      # PixieLens answers focus point and texts in one response, and Feature::Embedding caches
      # that response for three days keyed by url, languages and generate_tags. Both endpoints
      # therefore ask with identical arguments -- otherwise generating a focus point and
      # generating a description for the same image would pay for two requests instead of one.
      result = embedding.embedding(image_url:, languages: [image_annotation_locale], generate_tags: true)
      return render_image_annotation_error(DataCycleCore::LocalizationService.translate_and_substitute(result.error, helpers.active_ui_locale)) if result.try(:error).present?
      # an enabled service answering with nothing is an outage, not a configuration problem
      return render_image_annotation_error(I18n.t('validation.errors.embedding_endpoint_error', locale: helpers.active_ui_locale)) if result.blank?

      render json: yield(feature.annotation_data(result), content)
    rescue DataCycleCore::Generic::Common::Error::EndpointError, Faraday::Error => e
      translation_key = e.is_a?(Faraday::ForbiddenError) ? 'validation.errors.embedding_forbidden_error' : 'validation.errors.embedding_endpoint_error'

      render_image_annotation_error(I18n.t(translation_key, locale: helpers.active_ui_locale))
    end

    # Whether a payload built from the stored annotation is an answer, i.e. holds a value under
    # any of its keys -- +{ focus_point: nil }+ and +{ texts: {} }+ do not.
    def image_annotation_answered?(payload)
      payload.is_a?(::Hash) && payload.values.any?(&:present?)
    end

    # The locale of the editor that asked. A wand sits in one translation of one attribute, and
    # the form renders the other translations without reloading the page, so the request names
    # its locale rather than leaving it to the request's own -- which is the locale of the
    # backend the editor is looking at, not of the field being filled.
    #
    # It also decides what the service is asked for, and PixieLens is billed per language: it
    # generates a caption, an ALT text and a title per requested language, each its own vision
    # call. Exactly one is asked for, because neither endpoint has a second to do anything with,
    # and it cannot be none -- an absent :languages: is answered with the service's own default
    # of [de, en], and an empty list raises on the languages[0] the service reads for its
    # geographic guess. Several languages are worth paying for only in the computed label
    # (Feature::ImageDescriptionPixie#generate_languages).
    #
    # @return [String]
    def image_annotation_locale
      create_locale(image_annotation_params)
    end

    # The content the suggestion is for: an existing thing, or an unsaved one standing in for the
    # image being uploaded. Deliberately without its asset, so the feature and permission guards
    # run before anything is looked up for it.
    def image_annotation_content
      return DataCycleCore::Thing.find_by(id: image_annotation_params[:thing_id]) if image_annotation_params[:thing_id].present?
      return if image_annotation_params[:template_name].blank?

      content = DataCycleCore::Thing.new(template_name: image_annotation_params[:template_name])
      content unless content.template_missing?
    rescue ActiveModel::MissingAttributeError # unknown template name
      nil
    end

    # Only reached once the feature guard confirmed the template carries an image asset property.
    def image_annotation_asset(content)
      return content.try(content.asset_property_names.first) if content.persisted?

      DataCycleCore::Asset.find_by(id: image_annotation_params[:asset_id])
    end

    def authorize_image_annotation!(content, asset)
      return authorize!(:update, content) if content.persisted?

      raise ActiveRecord::RecordNotFound if asset.blank?

      # :update rather than :read on the asset -- the read rule (AssetByUserAndNoContent) is a
      # query-only segment whose nested asset_content condition never matches a single record
      authorize! :update, asset
      authorize! :create, content
    end

    def render_image_annotation_error(message)
      render json: { error: message }, status: :unprocessable_content
    end

    def image_annotation_params
      @image_annotation_params ||= params.permit(:thing_id, :asset_id, :template_name, :locale)
    end
  end
end
