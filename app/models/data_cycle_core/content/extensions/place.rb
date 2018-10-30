# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Place
        def title
          name.presence || I18n.t('common.no_translation', locale: DataCycleCore.ui_language)
        end

        def desc
        end

        def address_line
          (try(:address)&.postal_code.present? || try(:address)&.address_locality.present? ? "#{address.postal_code} #{address.address_locality}, " : '') + (try(:address)&.street_address.present? ? address.street_address : '')
        end

        def address_block
          (try(:address)&.postal_code.present? || try(:address)&.address_locality.present? ? "#{address.postal_code} #{address.address_locality}<br>" : '') + (try(:address)&.street_address.present? ? address.street_address&.gsub(', ', '<br>') : '')
        end

        def coordinates
          "#{latitude}, #{longitude}" if latitude.present? && longitude.present?
        end

        def new_content_fields
          ['name']
        end

        def object_browser_fields
          ['name', 'address', 'location']
        end
      end
    end
  end
end
