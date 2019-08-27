# frozen_string_literal: true

module DataCycleCore
  module Serialize
    class GpxSerializer
      class << self
        def translatable?
          false
        end

        def mime_type(_content, _version)
          'gpx/xml'
        end

        def file_extension(_mime_type)
          '.gpx'
        end

        def serialize(content, _language, _version)
          builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
            xml.gpx(version: '1.1', creator: 'dataCycle', xmlns: 'http://www.topografix.com/GPX/1/1') do
              xml.metadata do
                xml.name content.title
                xml.desc ActionView::Base.full_sanitizer.sanitize(content.send('description')) if content.respond_to?('description')
                xml.time content.updated_at
                if content.created_by_user&.name.present?
                  xml.author do
                    xml.name content.created_by_user&.name
                  end
                end
              end
              content.geo_properties.each do |key, value|
                geo = content.send(key)
                geo = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true).parse_wkt(geo) if geo.is_a?(String)

                if geo.try(:geometry_type) == RGeo::Feature::Point
                  xml.wpt(lat: geo.y, lon: geo.x) do
                    xml.name value['label']
                    xml.ele geo.z if geo.z
                  end
                elsif geo.try(:geometry_type) == RGeo::Feature::LineString
                  xml.trk do
                    xml.name value['label']
                    xml.trkseg do
                      geo.points.each do |l|
                        xml.trkpt(lat: l.y, lon: l.x) do
                          xml.ele l.z if l.z
                        end
                      end
                    end
                  end
                end
              end
            end
          end

          builder.to_xml
        end
      end
    end
  end
end
