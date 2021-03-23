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
          @enabled ||= DataCycleCore.features.dig(name.demodulize.underscore.to_sym, :enabled) && dependencies_enabled?
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

        def allowed_attribute_key?(content, key)
          allowed?(content) && includes_attribute_key(content, key)
        end

        def includes_attribute_key(content, key)
          template_keys = attribute_keys(content)
          (key.scan(/\[(.*?)\]/).flatten & template_keys).any?
        end

        def configuration(content = nil)
          Rails.cache.fetch(cache_key(content)) do
            config = ActiveSupport::HashWithIndifferentAccess.new
            config.merge!(DataCycleCore.features.dig(name.demodulize.underscore.to_sym) || {})
            config.merge!(content&.schema&.dig('features', name.demodulize.underscore) || {})
            config.merge!(content&.collect_properties&.map { |key|
              content&.schema&.dig('properties', *key, 'features', name.demodulize.underscore).presence&.merge({ 'attribute_keys': (key.is_a?(Array) ? [key.last] : [key]), 'tree_label': content&.schema&.dig('properties', *key, 'tree_label') })
            }&.compact&.reduce({}) { |old, new| old.deep_merge(new) { |_, v1, v2| v1.is_a?(Array) && v2.is_a?(Array) ? v1 | v2 : v2 } } || {})
            config.compact
          end
        end

        def content_module
          false
        end

        def ability_class
          false
        end

        def data_hash_module
          false
        end

        def controller_module
          false
        end

        def cache_key(content)
          "#{name.underscore}_configuration_#{content&.id}_#{content&.updated_at}"
        end
      end
    end
  end
end
