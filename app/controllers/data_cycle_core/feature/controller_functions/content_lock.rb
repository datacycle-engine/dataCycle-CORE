# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module ContentLock
        extend ActiveSupport::Concern
        include ActionView::Helpers::DateHelper

        included do
          before_action :check_lock_state, only: [:edit, :merge_with_duplicate], if: -> { is_a?(DataCycleCore::ContentsController) } # rubocop:disable Lint/UnneededCopDisableDirective, Rails/LexicallyScopedActionFilter
          before_action :update_lock_state, only: :update, if: -> { is_a?(DataCycleCore::ContentsController) } # rubocop:disable Lint/UnneededCopDisableDirective, Rails/LexicallyScopedActionFilter

          before_action :check_lock_states, only: :bulk_edit, if: -> { is_a?(DataCycleCore::WatchListsController) } # rubocop:disable Lint/UnneededCopDisableDirective, Rails/LexicallyScopedActionFilter
          before_action :update_lock_states, only: :bulk_update, if: -> { is_a?(DataCycleCore::WatchListsController) } # rubocop:disable Lint/UnneededCopDisableDirective, Rails/LexicallyScopedActionFilter
        end

        private

        def check_lock_state
          @content ||= DataCycleCore::Thing.find(params[:id])

          redirect_back(fallback_location: root_path, alert: I18n.t(:content_locked, scope: [:common], user: @content.lock.user&.full_name, data: distance_of_time_in_words(@content.lock.locked_for), locale: DataCycleCore.ui_language)) && return if @content.locked? && @content.lock.user != current_user

          @content.lock.destroy if @content.locked?
          @content.reload_lock
          @content.create_lock(user: current_user)
        end

        def update_lock_state
          @content ||= DataCycleCore::Thing.find(params[:id])

          if @content.locked? && @content.lock.user != current_user
            redirect_back(fallback_location: root_path, alert: I18n.t(:content_locked, scope: [:common], user: @content.lock.user&.full_name, data: distance_of_time_in_words(@content.lock.locked_for), locale: DataCycleCore.ui_language)) && return
          elsif @content.locked?
            @content.lock.destroy
          end
        end

        def check_lock_states
          @watch_list ||= DataCycleCore::WatchList.find(params[:id])
          @contents = @watch_list.things
          content_locks = @contents.includes(:lock).map(&:lock).compact

          redirect_back(fallback_location: root_path, alert: I18n.t(:content_locked, scope: [:common], user: @content.lock.user&.full_name, data: distance_of_time_in_words(@content.lock.locked_for), locale: DataCycleCore.ui_language)) && return if content_locks.present? && content_locks.any? { |cl| cl.user != current_user }

          transaction do
            content_locks.each(&:destroy) if content_locks.present?
          end
          transaction do
            @contents.find_each do |c|
              c.reload_lock
              c.create_lock(user: current_user)
            end
          end
        end

        def update_lock_states
          @watch_list ||= DataCycleCore::WatchList.find(params[:id])
          @contents = @watch_list.things
          content_locks = @contents.includes(:lock).map(&:lock).compact

          redirect_back(fallback_location: root_path, alert: I18n.t(:content_locked, scope: [:common], user: @content.lock.user&.full_name, data: distance_of_time_in_words(@content.lock.locked_for), locale: DataCycleCore.ui_language)) && return if content_locks.present? && content_locks.any? { |cl| cl.user != current_user }

          transaction do
            content_locks.each(&:destroy) if content_locks.present?
          end
        end
      end
    end
  end
end
