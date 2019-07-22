# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module ContentLock
        extend ActiveSupport::Concern
        include ActionView::Helpers::DateHelper

        included do
          DataCycleCore::Engine.routes.append do
            scope '(/watch_lists/:watch_list_id)', defaults: { watch_list_id: nil } do
              get 'things/:id/renew_content_lock', action: :renew_content_lock, controller: 'things', as: 'renew_content_lock_thing' unless has_named_route?(:renew_content_lock_thing)
              post 'things/:id/unlock_content_lock', action: :unlock_content_lock, controller: 'things', as: 'unlock_content_lock_thing' unless has_named_route?(:unlock_content_lock_thing)
            end
          end
          Rails.application.reload_routes!

          before_action :check_lock_state, only: :edit # rubocop:disable Lint/UnneededCopDisableDirective, Rails/LexicallyScopedActionFilter
          before_action :update_lock_state, only: :update # rubocop:disable Lint/UnneededCopDisableDirective, Rails/LexicallyScopedActionFilter
        end

        def renew_content_lock
          @content = DataCycleCore::Thing.find(params[:id])

          return(head :ok) unless @content.lock&.user == current_user

          @content.lock&.touch
          head :ok
        end

        def unlock_content_lock
          @content = DataCycleCore::Thing.find(params[:id])

          return(head :ok) unless @content.lock&.user == current_user

          @content.lock.destroy
          head :ok
        end

        private

        def check_lock_state
          @content ||= DataCycleCore::Thing.find(params[:id])

          if @content.locked? && @content.lock.user != current_user
            redirect_back(fallback_location: root_path, alert: I18n.t(:content_locked, scope: [:common], user: @content.lock.user&.full_name, data: distance_of_time_in_words(@content.lock.locked_for), locale: DataCycleCore.ui_language)) && return
          elsif !@content.locked?
            @content.create_lock(user: current_user)
          end
        end

        def update_lock_state
          @content ||= DataCycleCore::Thing.find(params[:id])

          if @content.locked? && @content.lock.user != current_user
            redirect_back(fallback_location: root_path, alert: I18n.t(:content_locked, scope: [:common], user: @content.lock.user&.full_name, data: distance_of_time_in_words(@content.lock.locked_for), locale: DataCycleCore.ui_language)) && return
          elsif @content.locked?
            @content.lock.destroy
          end
        end
      end
    end
  end
end
