# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class AdvancedFilterByType < Base
        attr_reader :subject, :allowed_types

        def initialize(subject, allowed_types = {})
          @allowed_types = allowed_types.to_h.transform_keys(&:to_s)
          @subject = Array.wrap(subject).map(&:to_sym)
        end

        def include?(_view, _name = nil, type = nil, data = {}, *args)
          return true if type.nil?

          return false unless allowed_types.key?(type.to_s)

          respond_to?(:"#{type}_type", true) ? send(:"#{type}_type", data, *args) : default_type(type, data, *args)
        end

        def to_proc
          ->(*args) { include?(*args) }
        end

        private

        def to_restrictions(**)
          return if allowed_types.blank?

          to_restriction(except: Array.wrap(allowed_types.keys).map { |v| I18n.t("filter_groups.#{v}", locale:) }.join(', '))
        end

        def geo_filter_type(data, *_args)
          type = __method__
          allowed_types_transformed = allowed_types.dig(type.to_s).presence || allowed_types.dig(type.to_s.sub('_type', ''))
          case data.dig(:data, :advancedType)
          when 'geo_radius'
            allowed_types_transformed.dig('geo_radius')
          when 'geo_within_classification'
            Array.wrap(allowed_types_transformed.dig('geo_within_classification'))
              .include?(data.dig(:data, :name))
          else
            false
          end
        end

        def classification_alias_ids_type(data, *args)
          default_type(__method__, data, *args, key: :name)
        end

        def advanced_attributes_type(data, *args)
          default_type(__method__, data, *args, key: :name)
        end

        def default_type(type, data, *_args, key: :advancedType)
          allowed_types_transformed = allowed_types.dig(type.to_s).presence || allowed_types.dig(type.to_s.sub('_type', ''))
          return true if ['all', true].include?(allowed_types_transformed)
          Array.wrap(allowed_types_transformed).include?(data.dig(:data, key))
        end
      end
    end
  end
end
