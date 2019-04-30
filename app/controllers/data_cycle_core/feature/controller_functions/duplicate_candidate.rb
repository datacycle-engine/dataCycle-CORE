# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module DuplicateCandidate
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.append do
            get '/things/:id/merge_with_duplicate/:duplicate_id', action: :merge_with_duplicate, controller: 'things', as: 'merge_with_duplicate_thing' unless has_named_route?(:merge_with_duplicate_thing)
            post '/things/:id/false_positive_duplicate/:duplicate_id', action: :false_positive_duplicate, controller: 'things', as: 'false_positive_duplicate_thing' unless has_named_route?(:false_positive_duplicate_thing)
          end
          Rails.application.reload_routes!
        end

        def merge_with_duplicate
          @content = DataCycleCore::Thing.find(merge_params[:id])
          @duplicate = DataCycleCore::Thing.find(merge_params[:duplicate_id])
          authorize!(:merge_duplicates, @content)

          redirect_back(fallback_location: root_path, alert: (I18n.t :type_mismatch, scope: [:controllers, :error, :duplicate], locale: DataCycleCore.ui_language)) && return if @content.template_name != @duplicate.template_name
        end

        def false_positive_duplicate
          @content = DataCycleCore::Thing.find(merge_params[:id])
          @duplicate = DataCycleCore::Thing.find(merge_params[:duplicate_id])
          authorize!(:merge_duplicates, @content)

          DataCycleCore::ThingDuplicate
            .find(@duplicate.duplicate_candidates.with_fp.find_by(duplicate_id: @content.id).thing_duplicate_id)
            .update!(false_positive: true)

          I18n.with_locale(@duplicate.first_available_locale) do
            redirect_back(fallback_location: root_path, notice: (I18n.t :duplicate_false_positive, scope: [:controllers, :success], locale: DataCycleCore.ui_language, data: @duplicate.try(:title)))
          end
        end

        def merge_and_remove_duplicate
          @duplicate = DataCycleCore::Thing.find(merge_params[:duplicate_id])

          authorize!(:merge_duplicates, @content)

          redirect_back(fallback_location: root_path, alert: (I18n.t :type_mismatch, scope: [:controllers, :error, :duplicate], locale: DataCycleCore.ui_language)) && return if @content.template_name != @duplicate.template_name

          I18n.with_locale(@content.first_available_locale) do
            @content.merge_with_duplicate(@duplicate)

            flash[:success] = I18n.t :merged_with_duplicate, scope: [:controllers, :success], locale: DataCycleCore.ui_language
          end
        end

        private

        def merge_params
          params.permit(:id, :duplicate_id)
        end
      end
    end
  end
end
