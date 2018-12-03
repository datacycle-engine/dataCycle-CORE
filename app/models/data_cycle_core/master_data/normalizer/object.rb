# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      module Object
        def basic_types
          # [
          #   UNSPECIFIED,
          #   SEX,
          #   DEGREE,
          #   FORENAME,
          #   SURNAME,
          #   COMPANY,
          #   STREET,
          #   STREETNR,
          #   CITY,
          #   ZIP,
          #   COUNTRY,
          #   BIRTHDATE,
          #   EMAIL,
          #   ZIP_COUNTRY,
          #   CITY_ZIP,
          #   STREET_STREETNR,
          #   SURNAME_FORENAME
          # ]
        end

        def normalize(data, template_data, logger)
        end
      end
    end
  end
end
