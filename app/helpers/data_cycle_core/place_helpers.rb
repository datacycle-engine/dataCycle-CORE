module DataCycleCore
  module PlaceHelpers
    def title
      name || address_line || coordinates
    end

    def desc
    end

    def address_line
      "#{address.postal_code} #{address.address_locality}, #{address.street_address}" unless address.to_h.blank?
    end

    def coordinates
      "#{latitude}, #{longitude}" unless latitude.blank? || longitude.blank?
    end
  end
end
