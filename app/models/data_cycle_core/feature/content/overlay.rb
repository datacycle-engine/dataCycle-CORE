# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Content
      module Overlay
        def overlay?
          overlay.size.positive?
        end

        def overlay_name
          @overlay_name ||= DataCycleCore.features.dig('overlay', 'attribute_keys')&.first
        end

        def overlay_template_name
          @overlay_template_name ||= properties_for(overlay_name)&.dig('template_name') if overlay_name.present?
        end

        def overlay_property_names
          @overlay_property_names ||= DataCycleCore::Thing.find_by(template_name: overlay_template_name, template: true)&.property_names
        end

        def overlay_data(locale)
          @overlay_data ||= Hash.new do |h, key|
            h[key] = send(overlay_name).first.try(:get_data_hash)
          end
          @overlay_data[locale]
        end
      end
    end
  end
end
