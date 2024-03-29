# frozen_string_literal: true

Hash.class_eval do
  # !!ATTENTION!!
  # This method is intendend to be used only for configuration files provided by developers. It is not intended to be
  # used for values provided by end users.
  def with_evaluated_values(current_binding = binding)
    to_h do |key, value|
      # allow also evaluated keys
      key = eval(key[2..-3], current_binding) if key.is_a?(String) && /{{.*}}/.match?(key) # rubocop:disable Security/Eval
      key = eval(key[2..-3], current_binding).to_sym if key.is_a?(Symbol) && /{{.*}}/.match?(key.to_s) # rubocop:disable Security/Eval

      if value.is_a?(Hash) || value.is_a?(Array)
        [key, value.with_evaluated_values(current_binding)]
      elsif value.is_a?(String) && /{{.*}}/.match?(value)
        [key, eval(value[2..-3], current_binding)] # rubocop:disable Security/Eval
      else
        [key, value]
      end
    end
  end
end

Array.class_eval do
  # !!ATTENTION!!
  # This method is intendend to be used only for configuration files provided by developers. It is not intended to be
  # used for values provided by end users.
  def with_evaluated_values(current_binding = binding)
    map do |value|
      if value.is_a?(Hash) || value.is_a?(Array)
        value.with_evaluated_values(current_binding)
      elsif value.is_a?(String) && /{{.*}}/.match?(value)
        eval(value[2..-3], current_binding) # rubocop:disable Security/Eval
      else
        value
      end
    end
  end
end
