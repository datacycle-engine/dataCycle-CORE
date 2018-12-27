# frozen_string_literal: true

module DataCycleCore
  module ApiHelper
    include DataHashHelper

    def render_api_attribute(key:, definition:, value:, parameters: {}, content: nil, _scope: :api)
      partials = [
        key.underscore.to_s,
        "#{definition['type'].underscore}_#{definition.try(:[], 'api').try(:[], 'partial').try(:underscore)}",
        "#{definition['type'].underscore}_#{definition.try(:[], 'validations').try(:[], 'format').try(:underscore)}",
        "#{definition.try(:[], 'compute').try(:[], 'type').try(:underscore)}_#{definition.try(:[], 'api').try(:[], 'partial').try(:underscore)}",
        definition.try(:[], 'compute').try(:[], 'type').try(:underscore).to_s,
        definition['type'].underscore.to_s,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/api/v2/api_base/attributes/#{p}" }
      return first_existing_partial(partials), parameters.merge({ key: key, definition: definition, value: value, content: content })
    end

    def first_existing_partial(partials)
      partials.each_with_index do |partial, _idx|
        next unless lookup_context.exists?(partial, [], true)
        return partial
      end
    end
  end
end
