# frozen_string_literal: true

module DataCycleCore
  DataAttribute = Struct.new(:key, :definition, :options, :content, :scope, :specific_scope) do
    def initialize(key, definition, options, content, scope, specific_scope = nil)
      if options.is_a?(ActionController::Parameters)
        options = options.permit!.to_h
      elsif options.is_a?(Hash)
        options = options.with_indifferent_access
      elsif options.nil?
        options = {}
      end

      if definition.is_a?(ActionController::Parameters)
        definition = definition.permit!.to_h
      elsif definition.is_a?(Hash)
        definition = definition.with_indifferent_access
      elsif options.nil?
        definition = {}
      else
        definition = definition.deep_dup
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

  DataAttributeModel = Struct.new(:klass) do
    def human(**)
      I18n.t("activerecord.models.#{klass.name.underscore}", **)
    end
  end
end
