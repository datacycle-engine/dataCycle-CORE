# frozen_string_literal: true

Rails.application.reloader.to_prepare do
  Rails.application.configure do
    Dry::Logic::Predicates.predicate(:uuid_v4_or_list_of_uuid_v4?) do |value|
      value.is_a?(String) && value.split(',').all? { |uuid| uuid_v4?(uuid) }
    end

    Dry::Logic::Predicates.predicate(:api_sort_parameter?) do |value|
      next false unless value.is_a?(String)
      next true unless value.starts_with?('random')
      _key, _order, v = DataCycleCore::ApiService.order_key_with_value(value)

      v = v.to_f if v.is_a?(String)

      v.nil? || v.between?(-1, 1)
    end

    Dry::Logic::Predicates.predicate(:uuid_v4_or_null_string?) do |value|
      value.is_a?(String) && (uuid_v4?(value) || format?(/^NULL$/i, value))
    end

    Dry::Logic::Predicates.predicate(:api_weight_string?) do |value|
      value.is_a?(String) && format?(/^[ABCD]{1,4}$/i, value)
    end
  end
end
