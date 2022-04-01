# frozen_string_literal: true

module DataCycleCore
  module Content
    module ContentOverlay
      def overlay?
        return false unless content_type == 'entity'
        return false unless respond_to?(overlay_name)
        send(overlay_name).size.positive?
      end

      def overlay_name
        @overlay_name ||= DataCycleCore.features.dig('overlay', 'attribute_keys')&.first
      end

      def overlay_template_name
        @overlay_template_name ||= properties_for(overlay_name)&.dig('template_name') if overlay_name.present?
      end

      def overlay_property_names
        @overlay_property_names ||= DataCycleCore::Thing.find_by(template_name: overlay_template_name, template: true)&.property_names || []
      end
      alias overlay_properties overlay_property_names

      def overlay_property_definitions
        @overlay_property_definitions ||= DataCycleCore::Thing.find_by(template_name: overlay_template_name, template: true)&.schema&.dig('properties') || {}
      end

      def overlay_properties_for(overlay_property_name)
        overlay_property_definitions[overlay_property_name]
      end

      def overlay_data(locale)
        return unless overlay?
        @overlay_data ||= ActiveSupport::HashWithIndifferentAccess.new do |h, key|
          h[key] = send(overlay_name).first.try(:get_data_hash)
        end
        @overlay_data[locale]
      end

      def add_overlay_property_names
        overlay_property_names - property_names
      end
      alias add_overlay_properties add_overlay_property_names

      def add_overlay_property_definitions
        @add_overlay_property_definitions ||= Hash[*add_overlay_property_names.map { |prop| [prop, overlay_properties_for(prop)] }&.flatten]
      end

      def all_overlay_data
        @overlay_data
      end

      def property_names_with_overlay
        property_names + add_overlay_property_names
      end
    end
  end
end
