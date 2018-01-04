module DataCycleCore
  module PlaceTranslationHelpers
    def title
      name || address_line || coordinates
    end

    def desc
    end
  end
end
