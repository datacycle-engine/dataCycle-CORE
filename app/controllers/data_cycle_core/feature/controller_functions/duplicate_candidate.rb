# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module DuplicateCandidate
        extend ActiveSupport::Concern

        def merge_with_duplicate
          @content = DataCycleCore::Thing.find(merge_params[:id])
          @split_source = DataCycleCore::Thing.find(Array.wrap(merge_params[:source_id]).first)
          @source_locale = source_params[:source_locale] || @split_source.first_available_locale
          authorize!(:merge_duplicates, @content)

          redirect_back(fallback_location: root_path, alert: (I18n.t :cannot_merge_self, scope: [:controllers, :error, :duplicate], locale: helpers.active_ui_locale)) && return if @content.id == @split_source.id

          redirect_back(fallback_location: root_path, alert: (I18n.t :type_mismatch, scope: [:controllers, :error, :duplicate], locale: helpers.active_ui_locale)) && return if @content.template_name != @split_source.template_name

          I18n.with_locale(params[:locale] || @content.first_available_locale) do
            @locale = I18n.locale
            render && return
          end
        end

        def false_positive_duplicate
          @content = DataCycleCore::Thing.find(merge_params[:id])
          @duplicate = DataCycleCore::Thing.find(merge_params[:source_id])
          authorize!(:merge_duplicates, @content)

          DataCycleCore::ThingDuplicate
            .find(@duplicate.duplicate_candidates.with_fp.find_by(duplicate_id: @content.id).thing_duplicate_id)
            .update!(false_positive: true)

          I18n.with_locale(@duplicate.first_available_locale) do
            redirect_back(fallback_location: root_path, notice: (I18n.t :duplicate_false_positive, scope: [:controllers, :success], locale: helpers.active_ui_locale, data: @duplicate.try(:title)))
          end
        end

        def merge_and_remove_duplicate
          @duplicate = DataCycleCore::Thing.find(merge_params[:duplicate_id])

          authorize!(:merge_duplicates, @content)

          redirect_back(fallback_location: root_path, alert: (I18n.t :type_mismatch, scope: [:controllers, :error, :duplicate], locale: helpers.active_ui_locale)) && return if @content.template_name != @duplicate.template_name

          @content.merge_with_duplicate(@duplicate)
          flash[:success] = I18n.t('controllers.success.merged_with_duplicate', locale: helpers.active_ui_locale)
        end

        def validate_duplicate
          @content = DataCycleCore::Thing.find(merge_params[:id])
          @duplicate = DataCycleCore::Thing.find(merge_params[:source_id])
          authorize!(:edit, @content)

          valid = { valid: true }

          valid[:warnings] = { duplicate_candidates: I18n.t('duplicate.merge_warning_html', locale: helpers.active_ui_locale) } if @content.external_source_id.present? && @duplicate.external_source_id.blank?

          render json: valid
        end

        private

        def merge_params
          params.permit(:id, :source_id, :duplicate_id, source_id: [])
        end

        def version_name_for_merge(datahash)
          duplicate = DataCycleCore::Thing.find(merge_params[:duplicate_id])
          version_name = DataCycleCore::Feature::DuplicateCandidate.version_name_for_merge(duplicate, helpers.active_ui_locale)

          datahash[:version_name] = [
            datahash[:version_name],
            version_name
          ].compact_blank.join(' / ')
        end
      end
    end
  end
end
