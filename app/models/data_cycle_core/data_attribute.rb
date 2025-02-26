# frozen_string_literal: true

module DataCycleCore
  DataAttribute = Struct.new(:key, :definition, :options, :content, :scope, :specific_scope) do
    def initialize(key, definition, options, content, scope, specific_scope = nil)
      if options.is_a?(ActionController::Parameters)
        options = options.permit!.to_h
      elsif options.is_a?(::Hash)
        options = options.dc_deep_dup.with_indifferent_access
      else
        options = {}
      end

      if definition.is_a?(ActionController::Parameters)
        definition = definition.permit!.to_h
      elsif definition.is_a?(::Hash)
        definition = definition.dc_deep_dup.with_indifferent_access
      else
        definition = {}
      end

      specific_scope ||= scope

      if specific_scope != scope && definition.dig('ui', specific_scope.to_s).present?
        definition['ui'] ||= {}
        definition['ui'][scope.to_s] ||= {}
        definition['ui'][scope.to_s].merge!(definition.dig('ui', specific_scope.to_s))
      end

      super
    end

    def self.model_name
      DataAttributeModel.new(self)
    end
  end
end
