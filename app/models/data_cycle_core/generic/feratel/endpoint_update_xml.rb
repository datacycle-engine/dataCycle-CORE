# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module EndpointUpdateXml
        def updated_events_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id], changed_from:)
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters('DateTimeFrom' => changed_from.to_s(:long_datetime),
                          'Start' => (Time.zone.today - 1.year).strftime('%Y-%m-%d'),
                          'End' => (Time.zone.today + 10.years).strftime('%Y-%m-%d')) do
                xml.ChangedEvents('Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end
              xml.ChangedEvents do
                xml.Details
                xml.Documents
                xml.Descriptions
                xml.Links
                xml.Facilities
                xml.Addresses
                xml.CustomAttributes
                xml.HandicapFacilities
                xml.GuestCards
              end
            end
          end
        end

        def updated_accommodations_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id], changed_from:)
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters('DateFrom' => changed_from.to_s(:long_datetime),
                          'Start' => (Time.zone.today - 1.year).strftime('%Y-%m-%d'),
                          'End' => (Time.zone.today + 10.years).strftime('%Y-%m-%d')) do
                xml.ServiceProvider('Type' => 'Accommodation', 'Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end
              xml.ChangedServiceProviders do
                xml.Details
                xml.Documents
                xml.Descriptions
                xml.Links
                xml.Facilities
                xml.Addresses
                xml.HotSpots
                xml.Services do
                  xml.Details
                  xml.Descriptions
                  xml.Facilities
                  xml.Availabilities
                  xml.Products do
                    xml.Details
                    xml.Descriptions
                    xml.Links
                    xml.PriceDetails
                    xml.Availabilities
                    xml.Gaps
                    # not working properties
                    # xml.ArrivalDepartureTemplates
                    # xml.SalesRuleTemplates
                  end
                end
                xml.AdditionalServices do
                  xml.Details
                  xml.Descriptions
                  xml.Links
                  xml.Facilities
                  xml.AdditionalProducts do
                    xml.Details
                    xml.PriceDetails
                  end
                end
              end
            end
          end
        end

        def updated_additional_service_providers_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id], changed_from:)
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters('DateFrom' => changed_from.to_s(:long_datetime),
                          'Start' => (Time.zone.today - 1.year).strftime('%Y-%m-%d'),
                          'End' => (Time.zone.today + 10.years).strftime('%Y-%m-%d')) do
                xml.ServiceProvider('Type' => 'AdditionalService', 'Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end
              xml.ChangedServiceProviders do
                xml.Details
                xml.Documents
                xml.Descriptions
                xml.Links
                xml.Facilities
                xml.Addresses
                xml.HotSpots
                xml.AdditionalServices do
                  xml.Details
                  xml.Descriptions
                  xml.Links
                  xml.Facilities
                  xml.AdditionalProducts do
                    xml.Details
                    xml.PriceDetails
                  end
                end
              end
            end
          end
        end

        def updated_infrastructure_items_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id], changed_from:)
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters('DateFrom' => changed_from.to_s(:long_datetime),
                          'Start' => (Time.zone.today - 1.year).strftime('%Y-%m-%d'),
                          'End' => (Time.zone.today + 10.years).strftime('%Y-%m-%d')) do
                xml.ChangedInfrastructure('Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end
              xml.ChangedInfrastructures do
                xml.Details
                xml.Documents
                xml.Descriptions
                xml.Links
                xml.Addresses
                xml.HotSpots
                xml.CustomAttributes
                xml.HandicapFacilities
                xml.GuestCards
              end
            end
          end
        end
      end
    end
  end
end
