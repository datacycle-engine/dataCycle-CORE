# frozen_string_literal: true

Hash.class_eval do
  # !!ATTENTION!!
  # This method is intendend to be used only for configuration files provided by developers. It is not intended to be
  # used for values provided by end users.
  def with_evaluated_values
    map { |key, value|
      if value.is_a?(Hash) || value.is_a?(Array)
        [key, value.with_evaluated_values]
      elsif value.is_a?(String) && /{{.*}}/.match?(value)
        [key, eval(value[2..-3])] # rubocop:disable Security/Eval
      else
        [key, value]
      end
    }.to_h
  end
end

Array.class_eval do
  # !!ATTENTION!!
  # This method is intendend to be used only for configuration files provided by developers. It is not intended to be
  # used for values provided by end users.
  def with_evaluated_values
    map { |value|
      if value.is_a?(Hash) || value.is_a?(Array)
        value.with_evaluated_values
      elsif value.is_a?(String) && /{{.*}}/.match?(value)
        eval(value[2..-3]) # rubocop:disable Security/Eval
      else
        value
      end
    }
  end
end
