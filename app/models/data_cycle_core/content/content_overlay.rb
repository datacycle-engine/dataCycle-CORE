# frozen_string_literal: true

module DataCycleCore
  module Content
    module ContentOverlay
      def overlay?
        return false unless overlay_allowed?
        send(overlay_name).size.positive?
      end

      def overlay_allowed?
        return false if content_type != 'entity'
        respond_to?(overlay_name)
      end

      def overlay_name
        @overlay_name ||= DataCycleCore.features.dig('overlay', 'attribute_keys')&.first
      end

      def overlay_template_name
        @overlay_template_name ||= properties_for(overlay_name)&.dig('template_name') if overlay_name.present?
      end

      def overlay_property_names
        @overlay_property_names ||= overlay_template_name.present? ? Array.wrap(DataCycleCore::ThingTemplate.find_by(template_name: overlay_template_name)&.property_names) : []
      end
      alias overlay_properties overlay_property_names

      def overlay_property_definitions
        @overlay_property_definitions ||= overlay_template_name.present? ? DataCycleCore::ThingTemplate.find_by(template_name: overlay_template_name)&.schema&.dig('properties') || {} : {}
      end

      def overlay_properties_for(overlay_property_name)
        overlay_property_definitions[overlay_property_name]
      end

      def overlay_content
        send(overlay_name).first
      end

      def add_overlay_property_names
        overlay_property_names - property_names
      end
      alias add_overlay_properties add_overlay_property_names

      def add_overlay_property_definitions
        @add_overlay_property_definitions ||= Hash[*add_overlay_property_names.map { |prop| [prop, overlay_properties_for(prop)] }&.flatten]
      end

      def property_names_with_overlay
        property_names + add_overlay_property_names
      end

      def value_from_overlay(method_name, *args)
        return unless overlay_property_names.include?(args[0])

        overlay_content.send(method_name, *args) if overlay? && overlay_content.respond_to?(method_name)
      end

      # attribute_getter_method Extensions
      def load_json_attribute(*args)
        value = value_from_overlay(__method__, *args) if args[2]
        value || value.is_a?(FalseClass) ? value : super
      end

      def load_included_data(*args)
        value = super.to_h
        value.merge!(value_from_overlay(__method__, *args).to_h) if args[2]

        OpenStructHash.new(value, self, args[1]).freeze
      end

      def load_relation(*args)
        value = value_from_overlay(__method__, *args) if args[6]
        value.presence || super
      end

      def load_classifications(*args)
        value = value_from_overlay(__method__, *args) if args[1]
        value.presence || super
      end

      def load_schedule(*args)
        value = value_from_overlay(__method__, *args) if args[1]
        value.presence || super
      end
    end
  end
end
