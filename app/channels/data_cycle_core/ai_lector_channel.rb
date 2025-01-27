# frozen_string_literal: true

module DataCycleCore
  class AiLectorChannel < ApplicationCable::Channel
    PARAMS_SCHEMA = DataCycleCore::BaseSchema.params do
      required(:template_name).filled(:str?)
      required(:key).filled(:str?)
      required(:tip_key).filled(:str?)
      required(:identifier).filled(:str?)
      optional(:text).value(:str?)
      optional(:locale).value(:str?)
    end

    def subscribed
      reject && return if current_user.blank?
      stream_from channel_name
    end

    def unsubscribed
    end

    def receive(data)
      parsed_data = parsed_data(data)

      ActionCable.server.broadcast(channel_name, data.symbolize_keys.merge({ warning: I18n.t('feature.ai_lector.tips.warnings.no_data', locale: current_user.ui_locale) })) && return if parsed_data[:text].blank?

      result = DataCycleCore::Feature['AiLector'].new.get_tips(current_user:, **parsed_data.slice(:text, :locale, :template_name, :key, :tip_key).symbolize_keys) do |chunk|
        ActionCable.server.broadcast(channel_name, data.symbolize_keys.merge(chunk))
      end

      ActionCable.server.broadcast(channel_name, data.symbolize_keys.merge(result))
    rescue StandardError => e
      ActionCable.server.broadcast(channel_name, data.symbolize_keys.merge({ error: e.message || I18n.t('feature.ai_lector.errors.generic', locale: current_user.ui_locale) }))
    end

    private

    def channel_name
      "ai_lector_#{params[:window_id]}"
    end

    def parsed_data(data)
      result = PARAMS_SCHEMA.call(data)
      raise ActionController::BadRequest unless result.success?
      result.to_h.with_indifferent_access
    end
  end
end
