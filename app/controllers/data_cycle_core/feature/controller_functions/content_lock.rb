# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module ContentLock
        extend ActiveSupport::Concern
        include ActionView::Helpers::DateHelper
        include ActionView::Helpers::TagHelper
        include ActionView::Helpers::TranslationHelper
        include ActionView::Helpers::OutputSafetyHelper

        included do
          DataCycleCore::Engine.routes.prepend do
            get '/things/:id/check_lock', action: :check_lock_thing, controller: 'things', as: 'check_lock_thing' unless has_named_route?(:check_lock_thing)
            get '/watch_lists/:id/check_lock', action: :check_lock_watch_list, controller: 'watch_lists', as: 'check_lock_watch_list' unless has_named_route?(:check_lock_watch_list)
          end
          Rails.application.reload_routes!

          before_action :check_lock_state, only: [:edit, :merge_with_duplicate], if: -> { is_a?(DataCycleCore::ContentsController) } # rubocop:disable Lint/UnneededCopDisableDirective, Rails/LexicallyScopedActionFilter
          before_action :update_lock_state, only: :update, if: -> { is_a?(DataCycleCore::ContentsController) } # rubocop:disable Lint/UnneededCopDisableDirective, Rails/LexicallyScopedActionFilter

          before_action :check_lock_states, only: :bulk_edit, if: -> { is_a?(DataCycleCore::WatchListsController) } # rubocop:disable Lint/UnneededCopDisableDirective, Rails/LexicallyScopedActionFilter
          before_action :update_lock_states, only: :bulk_update, if: -> { is_a?(DataCycleCore::WatchListsController) } # rubocop:disable Lint/UnneededCopDisableDirective, Rails/LexicallyScopedActionFilter
        end

        def check_lock_thing
          @content = DataCycleCore::Thing.find(params[:id])

          content_locks = {}
          if @content.locked?
            content_locks['locks'] = { @content.lock.id => @content.locked_until&.to_i }
            content_locks['texts'] = { @content.lock.id => tag.span(tag.br + tag.br + tag.i(t('common.content_locked_with_name_html', user: @content.lock.user&.full_name, data: distance_of_time_in_words(@content.lock.locked_for), name: I18n.with_locale(@content&.first_available_locale) { @content.try(:title) }, locale: DataCycleCore.ui_language)), id: "content-lock-#{@content.lock.id}", class: 'content-locked-text') }
          end

          render json: content_locks.to_json
        end

        def check_lock_watch_list
          @watch_list = DataCycleCore::WatchList.find(params[:id])

          content_locks = @watch_list.things.includes(:translations, :lock).map(&:lock).compact.sort_by(&:updated_at).reverse!
          content_texts = content_locks.map { |cl| [cl.id, tag.span(tag.br + tag.br + tag.i(t('common.content_locked_with_name_html', user: cl.user&.full_name, data: distance_of_time_in_words(cl.locked_for), name: I18n.with_locale(cl.activitiable&.first_available_locale) { cl.activitiable.try(:title) }, locale: DataCycleCore.ui_language)), id: "content-lock-#{cl.id}", class: 'content-locked-text')] }.to_h

          render json: { locks: content_locks.map { |l| [l.id, l.locked_until&.to_i] }.to_h, texts: content_texts }.to_json
        end

        private

        def check_lock_state
          @content ||= DataCycleCore::Thing.find(params[:id])

          redirect_back(fallback_location: root_path, alert: I18n.t(:content_locked_html, scope: [:common], user: @content.lock.user&.full_name, data: distance_of_time_in_words(@content.lock.locked_for), locale: DataCycleCore.ui_language)) && return if @content.locked? && @content.lock.user != current_user

          @content.lock.destroy if @content.locked?
          @content.reload_lock
          @content.create_lock(user: current_user)
        end

        def update_lock_state
          @content ||= DataCycleCore::Thing.find(params[:id])

          if @content.locked? && @content.lock.user != current_user
            redirect_back(fallback_location: root_path, alert: I18n.t(:content_locked_html, scope: [:common], user: @content.lock.user&.full_name, data: distance_of_time_in_words(@content.lock.locked_for), locale: DataCycleCore.ui_language)) && return
          elsif @content.locked?
            @content.lock.destroy
          end
        end

        def check_lock_states
          @watch_list ||= DataCycleCore::WatchList.find(params[:id])
          @contents = @watch_list.things
          content_locks = @contents.includes(:lock).map(&:lock).compact

          redirect_back(fallback_location: root_path, alert: I18n.t(:content_locked_html, scope: [:common], user: content_locks.find { |c| c.user != current_user }.user&.full_name, data: distance_of_time_in_words(content_locks.find { |c| c.user != current_user }.locked_for), locale: DataCycleCore.ui_language)) && return if content_locks.present? && content_locks.any? { |cl| cl.user != current_user }

          content_locks.each(&:destroy) if content_locks.present?
          @contents.find_each do |c|
            c.reload_lock
            c.create_lock(user: current_user)
          end
        end

        def update_lock_states
          @watch_list ||= DataCycleCore::WatchList.find(params[:id])
          @contents = @watch_list.things
          content_locks = @contents.includes(:lock).map(&:lock).compact

          redirect_back(fallback_location: root_path, alert: I18n.t(:content_locked_html, scope: [:common], user: content_locks.find { |c| c.user != current_user }.user&.full_name, data: distance_of_time_in_words(content_locks.find { |c| c.user != current_user }.locked_for), locale: DataCycleCore.ui_language)) && return if content_locks.present? && content_locks.any? { |cl| cl.user != current_user }

          content_locks.each(&:destroy) if content_locks.present?
        end
      end
    end
  end
end