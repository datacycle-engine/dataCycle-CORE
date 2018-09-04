# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Place
        def title
          name.presence || address_line || coordinates || I18n.t('common.no_translation', locale: DataCycleCore.ui_language)
        end

        def desc
        end

        def address_line
          "#{address.postal_code} #{address.address_locality}, #{address.street_address}" if try(:address)&.to_h&.values&.presence&.any?(&:present?)
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
