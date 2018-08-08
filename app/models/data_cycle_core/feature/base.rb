# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Base
      attr_reader :content

      def initialize(content: nil)
        @content = content
      end

      class << self
        def enabled?(content = nil)
          configuration(content).dig('enabled') && dependencies_enabled?(content)
        end

        def dependencies_enabled?(content = nil)
          configuration(content).dig('dependencies').present? ? configuration(content).dig('dependencies')&.all? { |d| "data_cycle_core/feature/#{d}".classify.constantize.enabled? } : true
        end

        def attribute_keys(content)
          content.try(:schema)&.dig('features', name.demodulize.underscore)
        end

        def available?(content)
          attribute_keys(content).present?
        end

        def allowed?(content)
          enabled? && available?(content)
        end

        def allowed_attribute_keys(content)
          allowed?(content) ? attribute_keys(content) : []
        end

        def includes_attribute_key(content, key)
          template_keys = attribute_keys(content) || []
          (key.scan(/\[(.*?)\]/).flatten & template_keys).size.positive?
        end

        def controller_functions
          []
        end

        def attribute_key(content = nil)
          configuration(content).dig('attribute_key')
        end

        def configuration(content = nil)
          config = {}
          config = config.merge(DataCycleCore.features.dig(name.demodulize.underscore.to_sym) || {})
          config = config.merge(content&.schema&.dig('features', name.demodulize.underscore) || {})
          config = config.merge(content&.collect_properties&.map { |k| content&.schema&.dig('properties', *k, 'features', name.demodulize.underscore).presence&.merge({ 'attribute_key': (k.is_a?(Array) ? k.last : k), 'tree_label': content&.schema&.dig('properties', *k, 'tree_label') }) }.presence&.compact&.first || {})
          config&.deep_stringify_keys
        end
      end
    end
  end
end
