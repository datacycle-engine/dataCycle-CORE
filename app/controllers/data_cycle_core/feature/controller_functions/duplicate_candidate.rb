# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module DuplicateCandidate
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.append do
            scope '(/watch_lists/:watch_list_id)', defaults: { watch_list_id: nil } do
              get '/things/:id/merge_with_duplicate/:source_id', action: :merge_with_duplicate, controller: 'things', as: 'merge_with_duplicate_thing' unless has_named_route?(:merge_with_duplicate_thing)
              post '/things/:id/false_positive_duplicate/:source_id', action: :false_positive_duplicate, controller: 'things', as: 'false_positive_duplicate_thing' unless has_named_route?(:false_positive_duplicate_thing)
            end
          end
          Rails.application.reload_routes!
        end

        def merge_with_duplicate
          @content = DataCycleCore::Thing.find(merge_params[:id])
          @split_source = DataCycleCore::Thing.find(merge_params[:source_id])
          @source_locale = source_params[:source_locale] || @split_source.first_available_locale
          authorize!(:merge_duplicates, @content)

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

          I18n.with_locale(@content.first_available_locale) do
            @duplicate.original_id = @content.id
            @content.merge_with_duplicate(@duplicate)

            flash[:success] = I18n.t :merged_with_duplicate, scope: [:controllers, :success], locale: helpers.active_ui_locale
          end
        end

        private

        def merge_params
          params.permit(:id, :source_id, :duplicate_id)
        end

        def version_name_for_merge(datahash)
          duplicate = DataCycleCore::Thing.find(merge_params[:duplicate_id])

          datahash[:version_name] = [
            datahash[:version_name].presence,
            I18n.t('common.merged_with_version_name', name: I18n.with_locale(duplicate.first_available_locale) { duplicate.title }, id: duplicate.id)
          ].compact.join(' / ')
        end
      end
    end
  end
end
