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
          @enabled ||= DataCycleCore.features.dig(feature_key.to_sym, :enabled) && dependencies_enabled?
        end

        def feature_key
          name.delete_suffix('::Base').demodulize.underscore
        end

        def feature_path
          name.delete_suffix('::Base').underscore
        end

        def dependencies(content = nil)
          Array.wrap(configuration(content).dig(:dependencies))
        end

        def dependencies_enabled?(content = nil)
          dependencies(content).all? { |d| "data_cycle_core/feature/#{d}".classify.constantize.enabled? }
        end

        def dependencies_allowed?(content = nil)
          dependencies_enabled?(content) && dependencies(content).all? { |d| "data_cycle_core/feature/#{d}".classify.constantize.allowed?(content) }
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

          key.attribute_path_from_key.intersect?(template_keys)
        end

        def configuration(content = nil, attribute_key = nil)
          remove_instance_variable(:@configuration) if instance_variable_defined?(:@configuration)

          @configuration ||= Hash.new do |h, key|
            config = ActiveSupport::HashWithIndifferentAccess.new
            config.merge!(DataCycleCore.features.dig(feature_key.to_sym) || {})
            config.merge!(key[3]&.dig('features', feature_key) || {})
            config.merge!(key[4]&.filter_map { |k|
              key[3]&.dig('properties', *k, 'features', feature_key).presence&.merge({ attribute_keys: (k.is_a?(Array) ? [k.last] : [k]), tree_label: key[3]&.dig('properties', *k, 'tree_label') })
            }&.reduce({}) { |old, new| old.deep_merge(new) { |_, v1, v2| v1.is_a?(Array) && v2.is_a?(Array) ? v1 | v2 : v2 } } || {})

            h[key] = config.compact
          end

          @configuration[cache_key(content, attribute_key)]
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

        def reload
          remove_instance_variable(:@configuration) if instance_variable_defined?(:@configuration)
          remove_instance_variable(:@enabled) if instance_variable_defined?(:@enabled)
          self
        end

        def cache_key(content, key = nil)
          [
            feature_path,
            'configuration',
            content&.id,
            content.try(:schema),
            if key.present?
              content.try(:collect_properties)&.select { |v| v.is_a?(::Array) ? v.include?(key.attribute_name_from_key) : v == key.attribute_name_from_key }
            else
              content.try(:collect_properties)
            end
          ]
        end

        def model_name
          FeatureBaseModel.new(self)
        end
      end
    end

    FeatureBaseModel = Struct.new(:klass) do
      def human(**)
        I18n.t("activerecord.models.#{klass.feature_path}", **)
      end
    end
  end
end
