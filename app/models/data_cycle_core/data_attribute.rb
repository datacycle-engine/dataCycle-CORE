# frozen_string_literal: true

module DataCycleCore
  DataAttribute = Struct.new(:key, :definition, :options, :content, :scope, :specific_scope) do
    def initialize(key, definition, options, content, scope, specific_scope = nil)
      if options.is_a?(ActionController::Parameters)
        options = options.to_unsafe_hash
      elsif options.is_a?(Hash)
        options = options.with_indifferent_access
      elsif options.nil?
        options = {}
      end

      if definition.is_a?(ActionController::Parameters)
        definition = definition.to_unsafe_hash
      elsif definition.is_a?(Hash)
        definition = definition.with_indifferent_access
      elsif options.nil?
        definition = {}
      end

      specific_scope ||= scope

      super
    end
  end
end
