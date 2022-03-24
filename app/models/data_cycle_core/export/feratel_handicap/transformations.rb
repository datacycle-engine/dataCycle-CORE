# frozen_string_literal: true

module DataCycleCore
  module Export
    module FeratelHandicap
      module Transformations
        def self.make_xml(data, feratel_id, utility_object)
          config = utility_object.external_system.credentials(:export)
          feratel_classification_ids =
            (data.universal_classifications.to_a + data.certificate_classification.to_a)
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
                    if data.certification_period.present?
                      xml.Parameter('Name' => 'CertifiedFrom', 'Value' => data.certification_period&.certified_from)
                      xml.Parameter('Name' => 'CertifiedTo', 'Value' => data.certification_period&.certified_to)
                    end
                    data.available_locales.map do |locale|
                      I18n.with_locale(locale) do
                        next if data.public_pdf.blank?
                        xml.Parameter('Name' => "ShortReport#{locale.to_s.capitalize}", 'Value' => data.public_pdf.short_report) if data.public_pdf.short_report.present?
                        xml.Parameter('Name' => "Wheelchair#{locale.to_s.capitalize}", 'Value' => data.public_pdf.wheelchair) if data.public_pdf.wheelchair.present?
                        xml.Parameter('Name' => "Deaf#{locale.to_s.capitalize}", 'Value' => data.public_pdf.deaf) if data.public_pdf.deaf.present?
                        xml.Parameter('Name' => "Visual#{locale.to_s.capitalize}", 'Value' => data.public_pdf.visual) if data.public_pdf.visual.present?
                        xml.Parameter('Name' => "Mental#{locale.to_s.capitalize}", 'Value' => data.public_pdf.mental) if data.public_pdf.mental.present?
                      end
                    end
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
