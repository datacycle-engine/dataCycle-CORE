# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module Normalize
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.prepend do
            post '/things/:id/normalize', action: :normalize, controller: 'things', as: 'normalize_thing' unless has_named_route?(:normalize_thing)
          end
          Rails.application.reload_routes!
        end

        def normalize
          @content = DataCycleCore::Thing.find_by(id: params[:id])
          external_source = DataCycleCore::ExternalSystem.find_by(name: DataCycleCore.features.dig(:normalize, :external_source))

          render(plain: { error: I18n.t(:no_data, scope: [:validation, :warnings], data: 'Normalisierung', locale: helpers.active_ui_locale) }.to_json, content_type: 'application/json') && return if external_source.blank? || @content.blank?

          normalize_logger = DataCycleCore::Generic::Logger::LogFile.new('normalize')
          normalizer = DataCycleCore::MasterData::NormalizeData.new(logger: normalize_logger, host: external_source.credentials['host'], end_point: external_source.credentials['end_point'])

          object_params = content_params(@content.template_name)
          datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @content.schema)

          _normalized_data, diff = normalizer.normalize(datahash, @content.schema)

          render plain: diff.to_json, content_type: 'application/json'
        end
      end
    end
  end
end
