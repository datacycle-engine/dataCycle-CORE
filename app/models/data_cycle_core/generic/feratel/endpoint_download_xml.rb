# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module EndpointDownloadXml
        def create_marketing_groups_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.MarketingGroups('Show' => true)
          end
        end

        def create_categories_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.Categories('Show' => true)
          end
        end

        def create_hot_spots_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.HotSpots('Show' => true)
          end
        end

        def create_rating_visitors_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.RatingVisitors('Show' => true)
          end
        end

        def create_shop_item_groups_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.ShopItemGroups('Show' => true)
          end
        end

        def create_fallback_languages_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.FallbackLanguages('Show' => true)
          end
        end

        def create_link_types_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.LinkTypes('Show' => true)
          end
        end

        def create_handicap_groups_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.HandicapGroups('Show' => true)
          end
        end

        def create_handicap_types_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.HandicapTypes('Show' => true)
          end
        end

        def create_handicap_classifications_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.HandicapClassifications('Show' => true)
          end
        end

        def create_handicap_facility_groups_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.HandicapFacilityGroups('Show' => true)
          end
        end

        def create_handicap_facilities_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.HandicapFacilities('Show' => true)
          end
        end

        def create_visitor_tax_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.VisitorTax('Show' => true)
          end
        end

        def create_locations_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.Countries('Show' => true, 'IncludeTranslations' => true)
            xml.Regions('Show' => true, 'IncludeTranslations' => true)
            xml.Towns('Show' => true, 'IncludeTranslations' => true)
            xml.Districts('Show' => true, 'IncludeTranslations' => true)
          end
        end

        def create_holiday_themes_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.HolidayThemes('Show' => true)
          end
        end

        def create_infrastructure_types_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.InfrastructureTypes('Show' => true)
          end
        end

        def create_infrastructure_topics_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.InfrastructureTopics('Show' => true)
          end
        end

        def create_custom_attributes_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.CustomAttributes('Show' => true)
          end
        end

        def create_facility_groups_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.FacilityGroups('Show' => true)
          end
        end

        def create_facilities_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.Facilities('Show' => true)
          end
        end

        def create_service_codes_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.ServiceCodes('Show' => true)
          end
        end

        def create_stars_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.Stars('Show' => true)
          end
        end

        def create_guest_cards_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.GuestCards('Show' => true)
          end
        end

        def create_guest_card_classifications_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.GuestCardClassifications('Show' => true)
          end
        end

        def create_additional_service_types_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.AdditionalServiceTypes('Show' => true)
          end
        end

        def create_classifications_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.Classifications('Show' => true)
          end
        end

        def create_creative_commons_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.CreativeCommons('Show' => true)
          end
        end

        def create_rating_questions_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.RatingQuestions('Show' => true)
          end
        end

        def create_infrastructure_items_index_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters('ShowCreativeCommons' => true) do
                xml.Infrastructure('Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.Infrastructure do
                xml.Details('DateFrom' => '1980-01-01')
              end
            end
          end
        end

        def create_infrastructure_items_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id], item_ids: nil)
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters('ShowCreativeCommons' => true) do
                xml.PreSelectedInfrastructureIDs do
                  Array.wrap(item_ids).each do |id|
                    xml.Item(id)
                  end
                end
                xml.Infrastructure('Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.Infrastructure('ShowDataOwner' => true) do
                xml.Details('DateFrom' => '1980-01-01', 'IncludeMainTopicId' => true)
                xml.Documents('DateFrom' => '1980-01-01', 'IncludeResolution' => true)
                xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                xml.Links('DateFrom' => '1980-01-01')
                xml.Addresses('DateFrom' => '1980-01-01')
                xml.HotSpots('DateFrom' => '1980-01-01')
                xml.CustomAttributes('DateFrom' => '1980-01-01')
                xml.HandicapFacilities('DateFrom' => '1980-01-01')
                xml.HandicapClassifications('DateFrom' => '1980-01-01')
                xml.QualityDetails('DateFrom' => '1980-01-01')
                xml.GuestCards('DateFrom' => '1980-01-01')
              end
            end
          end
        end

        def create_additional_service_providers_index_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters('ShowCreativeCommons' => true) do
                xml.ServiceProvider('Type' => 'AdditionalService', 'Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.ServiceProviders do
                xml.Details('DateFrom' => '1980-01-01')
              end
            end
          end
        end

        def create_additional_service_providers_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id], item_ids: nil)
          start_date = Time.zone.now.to_s[0..9]
          end_date = (Time.zone.now + 2.years).to_s[0..9]
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters('ShowCreativeCommons' => true) do
                xml.PreSelectedServiceProviderIDs do
                  Array.wrap(item_ids).each do |id|
                    xml.Item(id)
                  end
                end
                xml.ServiceProvider('Type' => 'AdditionalService', 'Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.ServiceProviders('ShowDataOwner' => true, 'IncludeVTInfo' => true) do
                xml.Details('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                xml.Documents('DateFrom' => '1980-01-01', 'IncludeResolution' => true)
                xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                xml.Links('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                xml.Facilities('DateFrom' => '1980-01-01')
                xml.Addresses('DateFrom' => '1980-01-01', 'GetSettlementAddresses' => true)
                xml.RatingsAverage('DateFrom' => '1980-01-01')
                xml.CustomAttributes('DateFrom' => '1980-01-01')
                xml.HotSpots('DateFrom' => '1980-01-01')
                xml.QualityDetails('DateFrom' => '1980-01-01')
                xml.HousePackageMasters('DateFrom' => '1980-01-01')
                xml.AdditionalServices do
                  xml.Details('DateFrom' => '1980-01-01')
                  xml.Documents('DateFrom' => '1980-01-01', 'IncludeResolution' => true)
                  xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                  xml.Links('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                  xml.Facilities('DateFrom' => '1980-01-01')
                  xml.GuestCards('DateFrom' => '1980-01-01')
                  # xml.HandicapClassifications('DateFrom' => '1980-01-01')
                  xml.AdditionalProducts do
                    xml.Details('DateFrom' => '1980-01-01')
                    xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                    # xml.Prices('DateFrom' => '1980-01-01', 'Start' => start_date, 'End' => end_date) # do not work for additional services for now!
                    xml.PriceDetails('DateFrom' => '1980-01-01', 'Start' => start_date, 'End' => end_date)
                  end
                end
              end
            end
          end
        end

        def create_events_index_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters('ShowCreativeCommons' => true) do
                xml.Events('Start' => (Time.zone.today - 3.years).strftime('%Y-%m-%d'),
                           'End' => (Time.zone.today + 10.years).strftime('%Y-%m-%d'),
                           'Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.Events do
                xml.Details('DateFrom' => '1980-01-01')
              end
            end
          end
        end

        def create_events_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id], item_ids: nil)
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters('ShowCreativeCommons' => true) do
                xml.PreSelectedEventIDs do
                  Array.wrap(item_ids).each do |id|
                    xml.Item(id)
                  end
                end
                xml.Events('Start' => (Time.zone.today - 3.years).strftime('%Y-%m-%d'),
                           'End' => (Time.zone.today + 10.years).strftime('%Y-%m-%d'),
                           'Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.Events('ShowDataOwner' => true) do
                xml.Details('DateFrom' => '1980-01-01')
                xml.Documents('DateFrom' => '1980-01-01', 'IncludeResolution' => true)
                xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                xml.Links('DateFrom' => '1980-01-01')
                xml.Facilities('DateFrom' => '1980-01-01')
                xml.Addresses('DateFrom' => '1980-01-01')
                xml.CustomAttributes('DateFrom' => '1980-01-01')
                xml.HandicapFacilities('DateFrom' => '1980-01-01')
                xml.HandicapClassifications('DateFrom' => '1980-01-01')
                xml.QualityDetails('DateFrom' => '1980-01-01')
                xml.GuestCards('DateFrom' => '1980-01-01')
              end
            end
          end
        end

        def create_accommodations_index_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters('ShowCreativeCommons' => true) do
                xml.ServiceProvider('Type' => 'Accommodation', 'Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.ServiceProviders do
                xml.Details('DateFrom' => '1980-01-01')
              end
            end
          end
        end

        def create_accommodations_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id], item_ids: nil)
          start_date = Time.zone.now.to_s[0..9]
          end_date = (Time.zone.now + 2.years).to_s[0..9]
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters('ShowCreativeCommons' => true) do
                xml.PreSelectedServiceProviderIDs do
                  Array.wrap(item_ids).each do |id|
                    xml.Item(id)
                  end
                end
                xml.ServiceProvider('Type' => 'Accommodation', 'Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.ServiceProviders('ShowDataOwner' => true, 'IncludeVTInfo' => true) do
                xml.Details('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                xml.Documents('DateFrom' => '1980-01-01', 'IncludeResolution' => true)
                xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                xml.Links('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                xml.Facilities('DateFrom' => '1980-01-01')
                xml.Addresses('DateFrom' => '1980-01-01', 'GetSettlementAddresses' => true, 'DetailedInformation' => true)
                xml.HotSpots('DateFrom' => '1980-01-01')
                xml.MetaRating('DateFrom' => '1980-01-01', 'CheckMinAmount' => true)
                xml.HandicapFacilities('DateFrom' => '1980-01-01')
                xml.HandicapClassifications('DateFrom' => '1980-01-01')
                xml.GTC('DateFrom' => '1980-01-01')
                xml.QualityDetails('DateFrom' => '1980-01-01')
                xml.HousePackageMasters('DateFrom' => '1980-01-01')
                xml.Services do
                  xml.Details('DateFrom' => '1980-01-01')
                  # xml.Documents('DateFrom' => '1980-01-01', 'IncludeResolution' => true)
                  xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                  # xml.Links('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                  xml.Facilities('DateFrom' => '1980-01-01')
                  # xml.HandicapFacilities('DateFrom' => '1980-01-01')
                  xml.Products do
                    xml.Details('DateFrom' => '1980-01-01')
                    # xml.Documents('DateFrom' => '1980-01-01', 'IncludeResolution' => true)
                    xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                    # xml.Links('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                    xml.Prices('DateFrom' => '1980-01-01', 'SalesChannel' => @sales_channel_id)
                    # xml.PriceDetails('DateFrom' => '1980-01-01', 'SalesChannel' => @sales_channel_id, 'Start' => start_date, 'End' => end_date)
                    # xml.ArrivalDepartureTemplates('DateFrom' => '1980-01-01', 'SalesChannel' => @sales_channel_id, 'Start' => start_date, 'End' => end_date)
                    # xml.Availabilities('DateFrom' => '1980-01-01', 'SalesChannel' => @sales_channel_id, 'Start' => start_date, 'End' => end_date)
                    # xml.Gaps('DateFrom' => '1980-01-01', 'Start' => start_date, 'End' => end_date)
                  end
                end
                xml.AdditionalServices do
                  xml.Details('DateFrom' => '1980-01-01')
                  # xml.Documents('DateFrom' => '1980-01-01', 'IncludeResolution' => true)
                  xml.Links('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                  xml.Facilities('DateFrom' => '1980-01-01')
                  xml.AdditionalProducts do
                    xml.Details('DateFrom' => '1980-01-01')
                    # xml.Documents('DateFrom' => '1980-01-01', 'IncludeResolution' => true)
                    # xml.Links('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                    xml.Prices('DateFrom' => '1980-01-01', 'Start' => start_date, 'End' => end_date)
                    # xml.PriceDetails('DateFrom' => '1980-01-01', 'Start' => start_date, 'End' => end_date)
                  end
                end
              end
            end
          end
        end

        def create_packages_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          # start_date = Time.zone.now.to_s[0..9]
          # end_date = (Time.zone.now + 2.years).to_s[0..9]
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters('ShowCreativeCommons' => true) do
                xml.Packages('Status' => 'All', 'From' => '1980-01-01', 'To' => '2080-01-01')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.Packages do
                xml.Details('DateFrom' => '1980-01-01')
                xml.Documents('DateFrom' => '1980-01-01', 'IncludeResolution' => true)
                xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                xml.Links('DateFrom' => '1980-01-01')
                xml.Prices('DateFrom' => '1980-01-01')
                xml.ContentDescriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                # xml.Sections do
                #   xml.Details('DateFrom' => '1980-01-01')
                #   xml.Descriptions('DateFrom' => '1980-01-01')
                #   xml.Prices('DateFrom' => '1980-01-01')
                #   xml.Products do
                #     xml.Availabilities('DateFrom' => '1980-01-01')
                #     xml.Prices('DateFrom' => '1980-01-01')
                #   end
                # end
              end
            end
          end
        end

        def create_brochures_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters('ShowCreativeCommons' => true) do
                xml.ShopItem('Type' => 'Brochure')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.ShopItems do
                xml.Details('DateFrom' => '1980-01-01')
                xml.Documents('DateFrom' => '1980-01-01', 'IncludeResolution' => true)
                xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                xml.Links('DateFrom' => '1980-01-01')
                xml.Variations do
                  xml.Details('DateFrom' => '1980-01-01')
                  xml.Documents('DateFrom' => '1980-01-01', 'IncludeResolution' => true)
                  xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                  xml.Links('DateFrom' => '1980-01-01')
                end
              end
            end
          end
        end

        def create_package_containers_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          # start_date = Time.zone.now.to_s[0..9]
          # end_date = (Time.zone.now + 2.years).to_s[0..9]
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters('ShowCreativeCommons' => true) do
                xml.PackageContainer('From' => '1980-01-01', 'To' => '2080-01-01')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.PackageContainers do
                xml.Details('DateFrom' => '1980-01-01')
                xml.Documents('DateFrom' => '1980-01-01', 'IncludeResolution' => true)
                xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                xml.Links('DateFrom' => '1980-01-01')
                xml.AssignedProducts('DateFrom' => '1980-01-01')
              end
            end
          end
        end

        def create_key_value_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.KeyValues('GetLocalValues' => true, 'DateFrom' => '2000-01-01') do
              xml.Translations do
                Array(lang).each do |l|
                  xml.Language('Value' => l.to_s)
                end
              end

              yield(xml)
            end
          end
        end

        def create_serial_events_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.SerialEvents('Show' => true)
          end
        end

        def create_request_xml(range_code: 'RG', range_ids: @primary_range_id)
          Nokogiri::XML::Builder.new { |xml|
            xml.FeratelDsiRQ('xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                             'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
                             'xmlns' => 'http://interface.deskline.net/DSI/XSD') do
              xml.Request('Originator' => @pos_code, 'Company' => @company_code) do
                xml.Range('Code' => range_code) do
                  Array(range_ids).each do |range_id|
                    xml.Item('Id' => range_id)
                  end
                end

                yield(xml)
              end
            end
          }.to_xml
        end
      end
    end
  end
end
