# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module AutoTranslation
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.prepend do
            post '/things/:id/create_auto_translations', action: :create_auto_translations, controller: 'things', as: 'create_auto_translations_thing' unless has_named_route?(:create_auto_translations_thing)
            post '/things/:id/auto_translations', action: :auto_translations, controller: 'things', as: 'auto_translations_thing' unless has_named_route?(:auto_translations_thing)
          end
          Rails.application.reload_routes!
        end

        def create_auto_translations
          @content = DataCycleCore::Thing.find_by(id: params[:id])
          render(plain: { error: I18n.t(:no_data, scope: [:validation, :warnings], data: 'Normalisierung', locale: helpers.active_ui_locale) }.to_json, content_type: 'application/json') && return if @content.blank?

          logger = DataCycleCore::Generic::Logger::LogFile.new('auto_translate')
          created = @content.create_update_translations
          logger.info('auto_translations', "auto-translating: #{@content.id}")
          logger.info('auto_translations', created.to_s)

          render plain: created.to_json, content_type: 'application/json'
        end

        # def auto_translations
        #   byebug
        #   @content = DataCycleCore::Thing.find_by(id: params[:id])
        #   render(plain: { error: I18n.t(:no_data, scope: [:validation, :warnings], data: 'Normalisierung', locale: helpers.active_ui_locale) }.to_json, content_type: 'application/json') && return if @content.blank?
        #
        #   logger = DataCycleCore::Generic::Logger::LogFile.new('auto_translate')
        # end
      end
    end
  end
end
