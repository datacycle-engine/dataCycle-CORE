# frozen_string_literal: true

module DataCycleCore
  module Serialize
    module Serializer
      class Gpx < Base
        class << self
          include DataCycleCore::Common::Routing

          def translatable?
            false
          end

          def mime_type
            'application/gpx+xml'
          end

          def file_name_prefix(content)
            "#{content.id}_"
          end

          def serialize_thing(content:, language:, **_options)
            content = content.is_a?(Array) ? content : [content]
            DataCycleCore::Serialize::SerializedData::ContentCollection.new(
              content
                .select { |item| serializable?(item) }
                .map { |item| serialize(item, language) }
            )
          end

          private

          def serialize(content, _language)
            builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
              xml.gpx(version: '1.1', creator: 'dataCycle', xmlns: 'http://www.topografix.com/GPX/1/1') do
                xml.metadata do
                  xml.name content.title
                  xml.desc ActionView::Base.full_sanitizer.sanitize(content.send('description')) if content.respond_to?('description')
                  if content.created_by_user&.name.present?
                    xml.author do
                      xml.name content.created_by_user&.name
                    end
                  end
                  xml.link(href: api_v4_universal_url(id: content.id))
                  xml.time content.updated_at.iso8601
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
                  elsif geo.try(:geometry_type) == RGeo::Feature::MultiLineString
                    xml.trk do
                      xml.name value['label']
                      geo.each do |t|
                        xml.trkseg do
                          t.points.each do |l|
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
            end
            DataCycleCore::Serialize::SerializedData::Content.new(
              data: builder.to_xml,
              mime_type:,
              file_name: file_name(content:),
              id: content.id
            )
          end
        end
      end
    end
  end
end
