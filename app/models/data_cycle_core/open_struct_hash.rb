# frozen_string_literal: true

module DataCycleCore
  class OpenStructHash < OpenStruct
    def initialize(hash = nil, parent = nil, definition = nil)
      hash = hash.to_h { |k, v| [k, v.is_a?(::Hash) ? DataCycleCore::OpenStructHash.new(v) : v] }
      super(**hash, parent:, definition:)
    end

    def to_h
      if table.blank?
        as_hash = {}
      else
        as_hash = table.stringify_keys.except('parent', 'definition')
        struct_keys = as_hash.select { |_, v| v.is_a? self.class }.map(&:first)
        struct_keys.each { |key| as_hash[key] = as_hash[key].to_h.compact }
      end
      as_hash.compact
    end

    def blank?
      to_h.values.all?(&:blank?)
    end

    def attribute_translatable?(key, prop = nil)
      property_definition = prop.presence || definition&.dig('properties', key).presence
      return false if property_definition.blank?

      I18n.available_locales.many? &&
        parent&.translatable? &&
        property_definition&.dig('storage_location') == 'translated_value' &&
        property_definition&.dig('type') != 'object'
    end
  end
end
