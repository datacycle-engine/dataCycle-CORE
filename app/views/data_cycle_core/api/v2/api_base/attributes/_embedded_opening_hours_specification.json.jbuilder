# frozen_string_literal: true

render 'data_cycle_core/api/v2/api_base/attribute', key: key, definition: definition, value: value, options: options, content: content do
  key_new = definition.dig('api', 'name') || key.camelize(:lower)
  json.set! key_new do
    json.array!(value.presence&.includes(:translations, :classifications)&.map { |specification|
      if specification.time.present?
        specification.time.map do |time|
          [specification, time]
        end
      else
        [[specification, specification.time]]
      end
    }&.reduce(&:+)) do |specification_with_time|
      I18n.with_locale(specification_with_time.first.first_available_locale) do
        if specification_with_time.first.schema.present?
          json.content_partial! 'context', content: specification_with_time.first

          json.content_partial! 'properties',
                                content: specification_with_time.first,
                                options: options.merge(
                                  hidden_attributes: (options[:hidden_attributes] || []) + ['time', 'opens', 'closes']
                                )

          json.content_partial! 'properties', content: specification_with_time.second, options: options if specification_with_time.second.present?
        end
      end
    end
  end
end
