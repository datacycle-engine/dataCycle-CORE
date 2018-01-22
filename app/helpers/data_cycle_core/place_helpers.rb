module DataCycleCore
  module PlaceHelpers
    def title
      name || address_line || coordinates
    end

    def desc
    end

    def address_line
      unless address.to_h.blank?
        "#{address.postal_code} #{address.address_locality}, #{address.street_address}"
      end
    end

    def coordinates
      unless latitude.blank? || longitude.blank?
        "#{latitude}, #{longitude}"
      end
    end
  end
end
