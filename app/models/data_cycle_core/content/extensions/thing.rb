# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Thing
        extend ActiveSupport::Concern

        def title
          case schema_type
          when 'Organization', 'Event', 'CreativeWork', 'Product', 'Intangible'
            name
          when 'Person'
            "#{given_name} #{family_name}"
          when 'Place'
            name.presence || I18n.t('common.no_translation', locale: DataCycleCore.ui_language)
          end
        end

        def desc
          case schema_type
          when 'Organization', 'Event', 'CreativeWork', 'Product', 'Intangible'
            description
          when 'Person'
            content&.dig('job_title')
          end
        end

        def object_browser_fields
          # title is shown by default
          case schema_type
          when 'Organization', 'Event', 'CreativeWork', 'Product', 'Intangible'
            []
          when 'Person'
            ['honorific_prefix', 'job_title', 'contact_info']
          when 'Place'
            ['address', 'location']
          end
        end

        def address_line
          return if schema_type != 'Place'
          (try(:address)&.postal_code.present? || try(:address)&.address_locality.present? ? "#{address.postal_code} #{address.address_locality}, " : '') + (try(:address)&.street_address.present? ? address.street_address : '')
        end

        def address_block
          return if schema_type != 'Place'
          ((try(:address)&.street_address.present? ? "#{address.street_address}<br/>" : '') + (try(:address)&.postal_code.present? || try(:address)&.address_locality.present? ? "#{address.postal_code} #{address.address_locality}" : ''))
        end

        def coordinates
          "GPS: #{latitude.round(2)}, #{longitude.round(2)}" if latitude.present? && longitude.present?
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
