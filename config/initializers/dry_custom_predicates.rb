# frozen_string_literal: true

Rails.application.reloader.to_prepare do
  Rails.application.configure do
    Dry::Logic::Predicates.predicate(:uuid_or_list_of_uuid?) do |value|
      value.is_a?(String) && value.split(',').map(&:strip).all? { |uuid| format?(DataCycleCore::StringExtension::UUID_REGEX, uuid) }
    end

    Dry::Logic::Predicates.predicate(:api_sort_parameter?) do |value|
      next false unless value.is_a?(String)
      next true unless value.starts_with?('random')
      _key, _order, v = DataCycleCore::ApiService.order_key_with_value(value)

      v = v.to_f if v.is_a?(String)

      v.nil? || v.between?(-1, 1)
    end

    Dry::Logic::Predicates.predicate(:uuid_or_null_string?) do |value|
      value.is_a?(String) && (format?(DataCycleCore::StringExtension::UUID_REGEX, value) || format?(/^NULL$/i, value))
    end

    Dry::Logic::Predicates.predicate(:api_weight_string?) do |value|
      value.is_a?(String) && format?(/^[ABCD]{1,4}$/i, value)
    end

    Dry::Logic::Predicates.predicate(:uuid?) do |value|
      value.is_a?(String) && format?(DataCycleCore::StringExtension::UUID_REGEX, value)
    end

    Dry::Logic::Predicates.predicate(:ruby_module_or_class?) do |value|
      value.is_a?(String) && value.safe_constantize&.class&.in?([Module, Class])
    end

    Dry::Logic::Predicates.predicate(:ruby_module?) do |value|
      value.is_a?(String) && value.safe_constantize&.class == Module
    end

    Dry::Logic::Predicates.predicate(:ruby_class?) do |value|
      value.is_a?(String) && value.safe_constantize&.class == Class
    end

    Dry::Logic::Predicates.predicate(:fields_wildcard?) do |value|
      value.is_a?(String) && value.split(',').map(&:strip).all? { |field| [field.length - 1, nil].include? field.index '*' }
    end
  end
end
