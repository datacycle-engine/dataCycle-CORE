# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module EndpointDeletedXml
        def create_mark_deleted_accommodations_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id], deleted_from:)
          from_date = deleted_from.strftime('%Y-%m-%d')
          from_date = '2010-01-01'
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.DeletedItems('DateFrom' => from_date) do
                xml.DeletedItem('Type' => 'ServiceProviders')
              end
            end
          end
        end

        def create_mark_deleted_events_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id], deleted_from:)
          from_date = deleted_from.strftime('%Y-%m-%d')
          from_date = '2010-01-01'
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.DeletedItems('DateFrom' => from_date) do
                xml.DeletedItem('Type' => 'Events')
              end
            end
          end
        end

        def create_mark_deleted_infrastructure_items_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id], deleted_from:)
          from_date = deleted_from.strftime('%Y-%m-%d')
          from_date = '2010-01-01'
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.DeletedItems('DateFrom' => from_date) do
                xml.DeletedItem('Type' => 'InfrastructureItems')
              end
            end
          end
        end
      end
    end
  end
end
