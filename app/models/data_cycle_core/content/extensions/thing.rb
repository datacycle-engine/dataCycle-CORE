# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Thing
        extend ActiveSupport::Concern

        def title(data_hash: nil)
          data_hash ||= {}

          case schema_type
          when 'Person'
            "#{data_hash['given_name']} #{data_hash['family_name']}".presence || "#{given_name} #{family_name}"
          when 'Place'
            data_hash['name'].presence || try(:name).presence || 'NO_TRANSLATION'
          else
            data_hash['name'].presence || try(:name)
          end
        end

        def desc
          case schema_type
          when 'Person'
            try(:job_title)
          else
            try(:description)
          end
        end

        def object_browser_fields
          # title is shown by default
          case schema_type
          when 'Person'
            ['honorific_prefix', 'job_title', 'contact_info']
          when 'Place'
            ['address', 'location']
          else
            []
          end
        end

        def address_line
          return if properties_for('address')&.[]('type') != 'object' || try(:address).blank?

          ActionView::OutputBuffer.new([
            [
              address.postal_code,
              address.address_locality
            ].compact_blank.join(' '),
            address.street_address
          ].compact_blank.join(', '))
        end

        def address_block
          return if properties_for('address')&.[]('type') != 'object' || try(:address).blank?

          ActionView::OutputBuffer.new([
            address.street_address,
            [
              address.postal_code,
              address.address_locality
            ].compact_blank.join(' ')
          ].compact_blank.join('<br>'))
        end

        def coordinates
          "GPS: #{latitude.round(2)}, #{longitude.round(2)}" if latitude.present? && longitude.present?
        end

        def icon_type
          template_name.underscore_blanks
        end

        def base_template_name
          template_name
        end

        # return all template_names, whose configuration is relevant for this thing
        def relevant_template_names
          [template_name]
        end

        # return all property_names, whose configuration might be relevant for given key
        def relevant_property_names(key)
          attribute_name = key&.attribute_name_from_key

          return [] if attribute_name.blank? || !property?(attribute_name)

          [attribute_name]
        end

        module ClassMethods
          # Deprecated: no replacement
          def from_time(_time)
            raise DataCycleCore::Error::DeprecatedMethodError, "Deprecated method not implemented: #{__method__}"
          end

          # Deprecated: no replacement
          def to_time(_time)
            raise DataCycleCore::Error::DeprecatedMethodError, "Deprecated method not implemented: #{__method__}"
          end

          # Deprecated: no replacement
          def sort_by_proximity(_date = Time.zone.now)
            raise DataCycleCore::Error::DeprecatedMethodError, "Deprecated method not implemented: #{__method__}"
          end
        end
      end
    end
  end
end
