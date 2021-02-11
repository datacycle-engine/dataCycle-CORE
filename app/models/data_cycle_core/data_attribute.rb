# frozen_string_literal: true

module DataCycleCore
  DataAttribute = Struct.new(:key, :definition, :options, :content, :scope) do
    def initialize(key, definition, options = {}, content, scope)
      if options.is_a?(ActionController::Parameters)
        options = options.to_unsafe_hash
      elsif options.is_a?(Hash)
        options = options.with_indifferent_access
      end
      super
    end
  end
end
