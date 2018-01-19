module DataCycleCore
  class Place < DataHash
    class Translation < Globalize::ActiveRecord::Translation
      include ContentTranslationHelpers
      include PlaceTranslationHelpers
    end

    class History < DataHash
      # handle translations with gem Globalize
      translates :name, :headline, :description, :url, :hours_available, :content,
                 :properties, :release, :release_id, :release_comment, :history_valid

      content_relations table_name: 'places', postfix: 'history'

      include ContentHelpers
      belongs_to :place

      # callbacks
      before_destroy :destroy_relations, prepend: true

      def destroy_relations
        translations.delete_all
      end
    end
    has_many :histories, -> { order(created_at: :desc) }, class_name: 'DataCycleCore::Place::History', foreign_key: :place_id

    # handle translations with gem Globalize
    translates :name, :headline, :description, :url, :hours_available, :content,
               :properties, :release, :release_id, :release_comment

    # include content specific relations
    content_relations table_name: table_name

    # callbacks
    before_destroy :destroy_relations, prepend: true

    include ContentHelpers
    include PlaceHelpers

    # associations
    has_one :primaryImage, class_name: 'CreativeWork', primary_key: 'photo', foreign_key: 'id'

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end

    def create_gpx
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.gpx(version: '1.1', creator: 'dataCycle', xmlns: "http://www.topografix.com/GPX/1/1") {
          xml.metadata {
            xml.name title
            xml.time updated_at
            xml.author {
              xml.name creator&.first&.title
            } unless creator&.first&.title.blank?
          }
          if location.try(:geometry_type) == RGeo::Feature::Point
            xml.wpt(lat: location.y, lon: location.x) {
              xml.name title
              xml.ele location.z if location.z
            }
          elsif location.try(:geometry_type) == RGeo::Feature::LineString
            xml.trk {
              xml.name title
              xml.trkseg {
                location.points.each do |l|
                  xml.trkpt(lat: l.y, lon: l.x){
                    xml.ele l.z if location.z
                  }
                end
              }
            }
          end
        }
      end

      builder.to_xml
    end

    private

    def destroy_relations
      translations.delete_all
      content_search_all.delete_all
    end
  end
end
