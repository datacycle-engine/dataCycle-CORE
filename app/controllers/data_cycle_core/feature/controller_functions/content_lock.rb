# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module ContentLock
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.append do
            scope '(/watch_lists/:watch_list_id)', defaults: { watch_list_id: nil } do
              get 'things/:id/renew_content_lock', action: :renew_content_lock, controller: 'things', as: 'renew_content_lock_thing' unless has_named_route?(:renew_content_lock_thing)
            end
          end
          Rails.application.reload_routes!

          after_action :check_lock, only: :edit
        end

        def renew_content_lock
          @content = DataCycleCore::Thing.find(params[:id])

          @content.lock&.touch
          head :ok
        end

        def check_lock
          if @content.locked? && @content.lock.user != current_user
            redirect_back(fallback_location: root_path, alert: I18n.t(:content_locked, scope: [:common], user: @content.lock.user&.full_name, data: distance_of_time_in_words(@content.lock.locked_for), locale: DataCycleCore.ui_language)) && return
          elsif !@content.locked?
            @content.create_lock(user: current_user)
          end
        end
      end
    end
  end
end
