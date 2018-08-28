# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Base
      attr_reader :content

      def initialize(content: nil)
        @content = content
      end

      class << self
        def enabled?
          DataCycleCore.features.dig(name.demodulize.underscore.to_sym, :enabled) && dependencies_enabled?
        end

        def dependencies_enabled?
          !DataCycleCore.features.dig(name.demodulize.underscore.to_sym, :dependencies)&.any? { |d| !"data_cycle_core/feature/#{d}".classify.constantize.enabled? }
        end

        def dependencies_allowed?(content = nil)
          dependencies_enabled? && !DataCycleCore.features.dig(name.demodulize.underscore.to_sym, :dependencies)&.any? { |d| !"data_cycle_core/feature/#{d}".classify.constantize.allowed?(content) }
        end

        def attribute_keys(content = nil)
          configuration(content).dig('attribute_keys') || []
        end

        def available?(content = nil)
          attribute_keys(content).present?
        end

        def allowed?(content = nil)
          enabled? && configuration(content).dig('allowed')
        end

        def allowed_attribute_keys(content = nil)
          allowed?(content) ? attribute_keys(content) : []
        end

        def includes_attribute_key(content, key)
          template_keys = attribute_keys(content) || []
          (key.scan(/\[(.*?)\]/).flatten & template_keys).size.positive?
        end

        def controller_functions
          []
        end

        def configuration(content = nil)
          config = {}
          config = config.merge(DataCycleCore.features.dig(name.demodulize.underscore.to_sym) || {})
          config = config.merge({ name.demodulize.underscore => content&.schema&.dig('features', name.demodulize.underscore) }.compact)
          config = config.merge(content&.collect_properties&.map { |k| content&.schema&.dig('properties', *k, 'features', name.demodulize.underscore).presence&.merge({ 'attribute_keys': (k.is_a?(Array) ? [k.last] : [k]), 'tree_label': content&.schema&.dig('properties', *k, 'tree_label') }) }.presence&.compact&.first || {})
          config&.deep_stringify_keys
        end
      end
    end
  end
end
