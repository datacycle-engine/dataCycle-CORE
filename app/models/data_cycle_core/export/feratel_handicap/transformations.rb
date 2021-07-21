# frozen_string_literal: true

module DataCycleCore
  module Export
    module FeratelHandicap
      module Transformations
        def self.make_xml(data, utility_object)
          config = utility_object.external_system.credentials(:export)
          feratel_id = data.linked_thing.find_by(template_name: 'Unterkunft')&.external_key
          feratel_classification_ids =
            data
              .universal_classifications
              .map { |c|
                c
                  .classification_aliases
                  .map { |l| l.classification_tree_label.name == 'Feratel - HandicapFacilities' ? l : nil }
                  .compact
              }
              .flatten
              .map { |c| c.primary_classification.external_key }
              .map { |c| c.split(' - ').last }
              .join(',')
          Nokogiri::XML::Builder.new { |xml|
            xml.FeratelDsiRQ('xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                             'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
                             'xmlns' => 'http://interface.deskline.net/DSI/XSD') do
              xml.Request('Company' => config['company_code']) do
                xml.GetResult('Code' => config['pos_code']) do
                  xml.Parameters do
                    xml.Parameter('Name' => 'GUID', 'Value' => feratel_id)
                    xml.Parameter('Name' => 'FacilityList', 'Value' => feratel_classification_ids)
                  end
                end
              end
            end
          }.to_xml
        end
      end
    end
  end
end
