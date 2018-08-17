# frozen_string_literal: true

module DataCycleCore
  module GpxConverter
    def create_gpx
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.gpx(version: '1.1', creator: 'dataCycle', xmlns: 'http://www.topografix.com/GPX/1/1') do
          xml.metadata do
            xml.name title
            xml.desc ActionView::Base.full_sanitizer.sanitize(send('description')) if respond_to?('description')
            xml.time updated_at
            if creator&.first&.name.present?
              xml.author do
                xml.name creator&.first&.name
              end
            end
          end
          geo_properties.each do |key, value|
            geo = send(key)
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
