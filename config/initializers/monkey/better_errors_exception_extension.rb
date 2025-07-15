# frozen_string_literal: true

module DataCycleCore
  module BetterErrorsExceptionExtension
    prepend_features Exception

    def to_yaml
      remove_instance_variable(:@__better_errors_bindings_stack) if instance_variable_defined?(:@__better_errors_bindings_stack)
      super
    end
  end
end
