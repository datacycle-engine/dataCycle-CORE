# frozen_string_literal: true

module DataCycleCore
  class AiLectorChannel < ApplicationCable::Channel
    PARAMS_SCHEMA = DataCycleCore::BaseSchema.params do
      required(:template_name).filled(:str?)
      required(:key).filled(:str?)
      required(:tip_key).filled(:str?)
      required(:identifier).filled(:str?)
      required(:stream_id).filled(:str?)
      optional(:text).value(:str?)
      optional(:locale).value(:str?)
      optional(:prompt_type).value(:str?)
      optional(:feedback).value(:str?)
      optional(:previous_response).value(:str?)
      optional(:user_context).value(:str?)
      optional(:content_id).maybe(:str?)
    end

    def subscribed
      reject && return unless current_user.present? &&
                              DataCycleCore::Feature['AiLector'].enabled?

      stream_from channel_name
    end

    def unsubscribed
    end

    def receive(data)
      parsed_data = parsed_data(data)
      return_data = parsed_data.slice(:identifier, :stream_id)

      # Consider the text blank if it has no actual textual content — an "empty"
      # rich-text field can still send markup (e.g. "<p><br></p>"). Strip tags
      # first (the endpoint strips them before sending anyway) so effectively
      # empty input yields the "no_data" warning instead of a useless request.
      stripped_text = parsed_data[:text].to_s.strip_tags.strip

      if stripped_text.blank?
        warning = I18n.t('feature.ai_lector.tips.warnings.no_data', locale: current_user.ui_locale)
        ActionCable.server.broadcast(channel_name, return_data.merge(warning:))
        return
      end

      result = DataCycleCore::Feature['AiLector'].new(current_user:, **parsed_data).get_data do |chunk|
        ActionCable.server.broadcast(channel_name, return_data.merge(chunk))
      end

      ActionCable.server.broadcast(channel_name, return_data.merge({ **(result || {}), finished: true }))
    rescue StandardError => e
      error = if Rails.env.development?
                "#{e.message}<br>#{e.backtrace.first(10).join('<br>')}"
              elsif e.is_a?(Faraday::Error)
                I18n.t('feature.ai_lector.warnings.no_connection', locale: current_user.ui_locale)
              else
                I18n.t('feature.ai_lector.errors.generic', locale: current_user.ui_locale)
              end

      ActionCable.server.broadcast(channel_name, (return_data || {}).merge(error:))
    end

    private

    def channel_name
      "ai_lector_#{params[:window_id]}"
    end

    def parsed_data(data)
      result = PARAMS_SCHEMA.call(data)
      raise ActionController::BadRequest unless result.success?

      result.to_h.symbolize_keys
    end
  end
end
