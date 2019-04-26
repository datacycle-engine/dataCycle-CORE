# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module DuplicateCandidate
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.append do
            get '/things/:id/merge_with_duplicate/:duplicate_id', action: :merge_with_duplicate, controller: 'things', as: 'merge_with_duplicate_thing' unless has_named_route?(:merge_with_duplicate_thing)
          end
          Rails.application.reload_routes!

          after_action :merge_and_remove_duplicate, only: :update, if: -> { params[:duplicate_id].present? }
        end

        def merge_with_duplicate
          @content = DataCycleCore::Thing.find(merge_params[:id])
          @duplicate = DataCycleCore::Thing.find(merge_params[:duplicate_id])

          authorize!(:merge_duplicates, @content)

          redirect_back(fallback_location: root_path, alert: (I18n.t :type_mismatch, scope: [:controllers, :error, :duplicate], locale: DataCycleCore.ui_language)) && return if @content.template_name != @duplicate.template_name
        end

        private

        def merge_params
          params.permit(:id, :duplicate_id)
        end

        def merge_and_remove_duplicate
          @duplicate = DataCycleCore::Thing.find(merge_params[:duplicate_id])

          authorize!(:merge_duplicates, @content)

          redirect_back(fallback_location: root_path, alert: (I18n.t :type_mismatch, scope: [:controllers, :error, :duplicate], locale: DataCycleCore.ui_language)) && return if @content.template_name != @duplicate.template_name

          I18n.with_locale(@content.first_available_locale) do
            @content.merge_with_duplicate(@duplicate)
          end
        end
      end
    end
  end
end
