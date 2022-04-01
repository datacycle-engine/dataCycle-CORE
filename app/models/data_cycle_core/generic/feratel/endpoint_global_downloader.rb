# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module EndpointGlobalDownloader
        # only used for Feratel Gästeportal
        def global_categories(lang: :de)
          enumerate_items(:global_categories, '//Category', lang: lang)
        end

        def global_classifications(lang: :de)
          enumerate_items(:global_classifications, '//Classification', lang: lang)
        end

        def global_service_classifications(lang: :de)
          enumerate_items(:global_service_classifications, '//Classification', lang: lang)
        end

        def global_marketing_groups(lang: :de)
          enumerate_items(:global_marketing_groups, '//MarketingGroup', lang: lang)
        end

        def global_countries(lang: :de)
          enumerate_default_items(:global_countries, '//Country', lang: lang)
        end

        def global_hot_spot_types(lang: :de)
          enumerate_default_items(:global_hot_spot_types, '//HotSpotType', lang: lang)
        end

        def global_salutations(lang: :de)
          enumerate_default_items(:global_salutations, '//Salutation', lang: lang)
        end

        def global_facility_groups(lang: :de)
          enumerate_default_items(:global_facility_groups, '//FacilityGroup', lang: lang)
        end

        def global_facilities(lang: :de)
          enumerate_default_items(:global_facilities, '//Facility', lang: lang)
        end

        def global_infrastructure_types(lang: :de)
          enumerate_default_items(:global_infrastructure_types, '//InfrastructureType', lang: lang)
        end

        def global_link_types(lang: :de)
          enumerate_default_items(:global_link_types, '//LinkType', lang: lang)
        end

        def global_languages(lang: :de)
          enumerate_language_items(:global_languages, '//Language', lang: lang)
        end

        def global_fallback_languages(lang: :de)
          enumerate_language_items(:global_fallback_languages, '//Language', lang: lang)
        end

        def global_service_codes(lang: :de)
          enumerate_language_items(:global_service_codes, '//ServiceCode', lang: lang)
        end

        def create_global_countries_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_global_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.GuestCountries('Show' => true)
          end
        end

        def create_global_hot_spot_types_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_global_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.HotSpotTypes('Show' => true)
          end
        end

        def create_global_salutations_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_global_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.Salutations('Show' => true)
          end
        end

        def create_global_languages_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_global_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.Languages('Show' => true)
          end
        end

        def create_global_fallback_languages_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_global_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.FallbackLanguages('Show' => true)
          end
        end

        def create_global_categories_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_global_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.Categories('Show' => true)
          end
        end

        def create_global_classifications_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_global_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.Classifications('Show' => true)
          end
        end

        def create_global_creative_commons_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_global_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.CreativeCommons('Show' => true)
          end
        end

        def create_global_service_classifications_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_global_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.ServiceClassifications('Show' => true)
          end
        end

        def create_global_marketing_groups_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_global_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.MarketingGroups('Show' => true)
          end
        end

        def create_global_facility_groups_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_global_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.FacilityGroups('Show' => true)
          end
        end

        def create_global_facilities_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_global_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.Facilities('Show' => true)
          end
        end

        def create_global_service_codes_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_global_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.ServiceCodes('Show' => true)
          end
        end

        def create_global_infrastructure_types_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_global_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.InfrastructureTypes('Show' => true)
          end
        end

        def create_global_link_types_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_global_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.LinkTypes('Show' => true)
          end
        end

        def create_global_key_value_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.KeyValues('GetLocalValues' => false) do
              xml.Translations do
                Array(lang).each do |l|
                  xml.Language('Value' => l.to_s)
                end
              end

              yield(xml)
            end
          end
        end
      end
    end
  end
end
