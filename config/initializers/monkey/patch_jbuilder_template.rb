# frozen_string_literal: true

JbuilderTemplate.class_eval do
  def content_partial!(partial, parameters)
    if parameters[:content].model_name.element == 'thing'
      content_parameter = parameters[:content].schema_type.underscore
    else
      content_parameter = parameters[:content].model_name.element
    end
    partials = [
      "#{content_parameter}_#{parameters[:content].template_name.underscore}_#{partial}",
      "#{content_parameter}_#{partial}",
      "content_#{partial}"
    ]

    render_first_existing_partial(partials, parameters)
  end

  def render_attribute!(key:, definition:, value:, parameters: {}, content: nil, _scope: :api)
    partials = [
      key.underscore.to_s,
      "#{definition['type'].underscore}_#{definition.try(:[], 'ui').try(:[], 'api').try(:[], 'type').try(:underscore)}",
      "#{definition['type'].underscore}_#{definition.try(:[], 'validations').try(:[], 'format').try(:underscore)}",
      definition['type'].underscore.to_s,
      'default'
    ].reject(&:blank?).map { |p| "data_cycle_core/api/v2/api_base/attributes/#{p}" }

    render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
  end

  private

  def render_first_existing_partial(partials, parameters)
    partials.each_with_index do |partial, idx|
      return partial!(partial, parameters)
    rescue ActionView::MissingTemplate => e
      raise e if idx == partials.size - 1
    end
  end
end
