module DataCycleCore
  module PlaceHelpers
    def title
      name || address_line || coordinates
    end

    def desc
    end

    def address_line
      "#{address.postal_code} #{address.address_locality}, #{address.street_address}" if try(:address)&.to_h.present?
    end

    def coordinates
      "#{latitude}, #{longitude}" if latitude.present? && longitude.present?
    end
  end
end
