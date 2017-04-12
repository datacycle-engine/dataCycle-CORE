module DataCycleCore
  module OutdoorActive

    class Import

      def initialize ( uuid , incremental_update = false, page_size = 300, verbose = false )
        @external_source_id = uuid
        @download_page_size = page_size
        @verbose = verbose
        @incremental_update = incremental_update
        @log = DataCycleCore::Logger.new('outdooractive_import')
        init_db
      end

      def init_db
        @classifications_trees_label_id = init_or_create_classifications_trees_label('imported')
        @tree_label_id_creative_work =    init_or_create_classifications_trees_label('CreativeWork')

        @creative_works_classification_alias_id = check_for_tree_entry_with_classification_alias('ImageObject')
        if @creative_works_classification_alias_id.nil?
          @creative_works_classification_alias_id = insert_classification_alias_and_tree_entry('ImageObject', @tree_label_id_creative_work)
        end
      end

      def init_or_create_classifications_trees_label(label)
        if ClassificationsTreesLabel.where(name: label, external_source_id: @external_source_id).count < 1
          ClassificationsTreesLabel
            .new(name: label, seen_at: Time.zone.now, external_source_id: @external_source_id)
            .save
        end
        ClassificationsTreesLabel
          .where(name: label, external_source_id: @external_source_id)
          .first
          .id
      end

      def check_for_tree_entry_with_classification_alias(label)
        classification_alias_id = nil
        top_level_classifications_tree_entries = ClassificationsTree
          .where(
            external_source_id: @external_source_id,
            classifications_trees_label_id: @tree_label_id_creative_work,
            parent_classifications_alias_id: nil
          )
        top_level_classifications_tree_entries.each do |item|
          if item.sub_classifications_alias.name == label
            classification_alias_id = item.sub_classifications_alias.id
          end
        end
        classification_alias_id
      end

      def insert_classification_alias_and_tree_entry(label, tree_label)
        classification_alias = ClassificationsAlias.new(name: label, seen_at: Time.zone.now)
        classification_alias.save
        creative_works_classification_alias_id = classification_alias.id
        ClassificationsTree
          .new(
            external_source_id: @external_source_id,
            classifications_alias_id: creative_works_classification_alias_id,
            classifications_trees_label_id: tree_label,
            seen_at: Time.zone.now
          )
          .save
        creative_works_classification_alias_id
      end

    # main import functionality
      def import
        Mongoid.override_database(nil) #reset to default
        Mongoid.override_database("#{DownloadPoi.database_name}_#{@external_source_id}")

        import_logging do
          import_category
          import_region
          import_poi
        end

        Mongoid.override_database(nil) #reset to default
      end

    private

      def import_category
        import_classification_logging ('category') do
          DownloadCategory.all.each do |loaded_category|
            ActiveRecord::Base.transaction do
              data_hash = {
                'external_source_id' => @external_source_id,
                'external_key' => loaded_category.id,
                'external_type' => 'category',
                'name' => loaded_category.name,
                'seen_at' => Time.zone.now
              }
              upsert_classification_from_key(loaded_category.id, loaded_category.parent_id, data_hash)
            end
          end
        end
      end

      def import_region
        import_classification_logging ('region') do
          DownloadRegion.all.each do |load_region|
            ActiveRecord::Base.transaction do
              bbox = convert_bbox(load_region.bbox)
              region_hash = {
                'external_source_id' => @external_source_id,
                'external_key' => load_region.region_id,
                'external_type' => 'region',
                'name' => load_region.name,
                'description' => load_region.categoryTitle,
                'bbox' => bbox,
                'seen_at' => Time.zone.now
              }
              upsert_classification_from_key(load_region.region_id, load_region.parent_id, region_hash)
            end
          end
        end
      end

      def import_poi
        import_poi_logging do

          if @incremental_update
            indexes = DownloadPoiUpsert.all.map {|index| index.id }
          else
            indexes = DownloadPoi.all.map {|index| index.id }
          end
          updates = indexes.count

          print " " * 40 + "loading"
          DownloadPoi.in(_id: indexes).each do |load_poi|
            print '.' if (updates % @download_page_size) == 0
            updates-=1
            to_update_place = Place
              .where(external_source_id: @external_source_id,
                external_key: load_poi.id)
              .first_or_initialize

            ActiveRecord::Base.transaction do
              load_poi.dump.each do |lang, lang_dump|
                I18n.with_locale(lang) do
                  to_update_place.set_data(extract_place_data(lang_dump)).save
                end
              end
              create_classification_place_regions( load_poi.dump[load_poi.dump.keys.first]['regions'], to_update_place.id )
              create_classification_place_category( load_poi.dump[load_poi.dump.keys.first]['category'], to_update_place.id )
              create_classification_from_bool( 'winterActivity', load_poi.dump[load_poi.dump.keys.first]['winterActivity'], to_update_place.id )
              create_classification_from_string( 'frontendtype', load_poi.dump[load_poi.dump.keys.first]['frontendtype'], to_update_place.id )
              create_classification_from_string( 'source', load_poi.dump[load_poi.dump.keys.first]['meta']['source']['name'], to_update_place.id )
              create_creative_works_place( load_poi.dump[load_poi.dump.keys.first]['images'], to_update_place.id )
              set_primary_image( load_poi.dump[load_poi.dump.keys.first]['primaryImage'], to_update_place.id )
            end
          end
          puts "\n"
          DownloadPoiUpsert.delete_all if @incremental_update
        end
      end

      def upsert_classification_from_key(external_key, parent_external_key, data_hash)
        classification_id = upsert_classification(external_key, data_hash)
        unless parent_external_key.nil?
          parent_classification_id = Classification
            .where(external_source_id: @external_source_id, external_key: parent_external_key)
            .first
            .id
        else
          parent_classification_id = nil
        end
        upsert_classification_from_id(classification_id, parent_classification_id, data_hash)
      end

      def upsert_classification(external_key, data_hash)
        if external_key.nil?
          classification = Classification.new
        else
          classification = Classification
            .where(external_source_id: @external_source_id, external_key: external_key)
            .first_or_initialize
        end
        classification.set_data(data_hash).save
        return classification.id
      end

      def upsert_classification_group_alias (classification_id, name)
        classification_group = ClassificationsGroup
          .where(external_source_id: @external_source_id, classification_id: classification_id)
          .first_or_initialize
        classifications_alias_id = classification_group.classifications_alias_id

        if classifications_alias_id.nil?
          classifications_alias = ClassificationsAlias.new
          classifications_alias.set_data({'name' => name, 'seen_at' => Time.zone.now}).save
          classifications_alias_id = classifications_alias.id
        end
        classification_group.set_data({
          'classification_id' => classification_id,
          'classifications_alias_id' => classifications_alias_id,
          'seen_at' => Time.zone.now
        }).save
        return classifications_alias_id
      end

      def get_parent_classifications_alias_id(parent_external_key)
        unless parent_external_key.nil?
          parent_classification_id = get_id(Classification, :external_key, parent_external_key)
          parent_classifications_alias_id = ClassificationsGroup
            .where(external_source_id: @external_source_id, classification_id: parent_classification_id)
            .first
            .classifications_alias_id
        else
          parent_classifications_alias_id = nil
        end
        return parent_classifications_alias_id
      end

      def upsert_classification_tree (classifications_alias_id, parent_classifications_alias_id)
        data_tree_hash = {
          'external_source_id' => @external_source_id,
          'classifications_alias_id' => classifications_alias_id,
          'parent_classifications_alias_id' => parent_classifications_alias_id,
          'seen_at' => Time.zone.now
        }
        classification_tree = ClassificationsTree
          .where(
            external_source_id: @external_source_id,
            classifications_alias_id: classifications_alias_id,
            parent_classifications_alias_id: parent_classifications_alias_id,
            classifications_trees_label_id: @classifications_trees_label_id
          )
          .first_or_initialize
        classification_tree.set_data(data_tree_hash).save
      end

      def create_classification_place_regions( regions, place_id)
        return if regions.empty? # some records have no associated region
        regions['region'].each do |record|
          create_classification_place_from_key(record['id'], place_id)
        end
      end

      def create_classification_place_category(category, place_id)
        return if category.empty?
        create_classification_place_from_key(category['id'], place_id)
      end

      def create_classification_place_from_key(external_key, place_id)
        classification_id = get_id(Classification, :external_key, external_key)
        unless classification_id.nil?
          create_classification_place(classification_id, place_id)
          create_classification_place_for_ancestors(classification_id, place_id)
        end
      end

      def create_classification_place_for_ancestors(classification_id, place_id)
        classification_alias = ClassificationsAlias
          .joins(:classifications_groups)
          .where("classifications_groups.classification_id = ? AND classifications_groups.external_source_id= ?", classification_id, @external_source_id)
          .first
        tree_ancestors = ClassificationsTree
          .where(
            classifications_alias_id: classification_alias.id,
            external_source_id: @external_source_id,
            classifications_trees_label_id: @classifications_trees_label_id
            )
            .first
            .ancestors
        tree_ancestors.each do |tree_entry|
          ancestor_classification_alias_id = tree_entry.classifications_alias_id
          ancestor_classification_id = Classification
            .joins(:classifications_groups)
            .where("classifications_groups.classifications_alias_id = ? AND classifications_groups.external_source_id= ?", ancestor_classification_alias_id, @external_source_id)
            .first
            .id
          create_classification_place(ancestor_classification_id, place_id)
        end
      end

      def create_classification_from_bool(name, value, place_id)
        if value == true
          classification_id = get_id(Classification, :name, name)
          if classification_id.nil?
            data_hash = {
              'external_source_id' => @external_source_id,
              'external_type' => 'bool extracted from POI',
              'name' => name,
              'seen_at' => Time.zone.now
            }
            classification_id = upsert_classification_from_id(nil, nil, data_hash)
          end
          create_classification_place(classification_id, place_id)
        end
      end

      def create_classification_from_string(name, value, place_id)
        parent_classification_id = get_id(Classification, :name, name)
        if parent_classification_id.nil?
          parent_data_hash = {
            'external_source_id' => @external_source_id,
            'external_type' => 'string extracted from POI',
            'name' => name,
            'seen_at' => Time.zone.now
          }
          parent_classification_id = upsert_classification_from_id(nil,nil, parent_data_hash)
        end
        classification_id = get_id(Classification, :name, value)
        if classification_id.nil?
          child_data_hash = {
            'external_source_id' => @external_source_id,
            'external_type' => 'string extracted from POI',
            'name' => value,
            'seen_at' => Time.zone.now
          }
          classification_id = upsert_classification_from_id(nil, parent_classification_id, child_data_hash)
        end
        create_classification_place(parent_classification_id, place_id)
        create_classification_place(classification_id, place_id)
      end

      def upsert_classification_from_id(classification_id, parent_classification_id, data_hash)
        if classification_id.nil?
          classification = Classification.new
        else
          classification = Classification.where(id: classification_id).first
        end
        classification.set_data(data_hash).save

        classifications_alias_id = upsert_classification_group_alias(classification.id, data_hash['name'])
        if parent_classification_id.nil?
          parent_classifications_alias_id = nil
        else
          parent_classifications_alias_id = ClassificationsGroup
            .where(classification_id: parent_classification_id, external_source_id: @external_source_id)
            .first
            .classifications_alias_id
        end
        upsert_classification_tree(classifications_alias_id, parent_classifications_alias_id)
        return classification.id
      end

      def create_classification_place(classification_id, place_id)
        data_hash = {
          'external_source_id' => @external_source_id,
          'seen_at' => Time.zone.now,
          'place_id' => place_id,
          'classification_id' => classification_id
        }
        to_update_classifications_place = ClassificationsPlace
          .where(
            external_source_id: @external_source_id,
            place_id: place_id,
            classification_id: classification_id
          )
          .first_or_initialize
        to_update_classifications_place.set_data(data_hash).save
      end

      def create_creative_works_place( images, place_id)
        return if images.nil? || images.empty?
        images['image'].each do |record|
          # save image
          data_image = {
            'headline' => record['title'],
            'content' => {'url' => "http://img.oastatic.com/img/#{record['id']}/.jpg"},
            'metadata' => record['meta'].merge({external_key: record['id']}),
            'seen_at' => Time.zone.now,
            'position' => 0,
            'properties' => {'gallery' => record['gallery'].to_s},
            'external_source_id' => @external_source_id
          }
          to_update_image = CreativeWork
            .where(
              "metadata ->> 'external_key' = ? AND external_source_id = ?",
              record['id'],
              @external_source_id
            )
            .first_or_initialize
            .set_data(data_image)
          to_update_image.save

          # relation to place
          data_creative_works_place = {
            'external_source_id' => @external_source_id,
            'place_id_id' => place_id,
            'creative_work_id' => to_update_image.id,
            'seen_at' => Time.zone.now
          }
          to_update_place_creative_work = CreativeWorksPlace
            .where(
              external_source_id: @external_source_id,
              place_id: place_id,
              creative_work_id: to_update_image.id
            )
            .first_or_initialize
            .set_data(data_creative_works_place)
            .save

          # relation to classification
          data_classifications_creative_work = {
            'creative_work_id' => to_update_image.id,
            'classifications_alias_id' => @creative_works_classification_alias_id,
            'tag' => false,
            'classification' => false,
            'seen_at' => Time.zone.now
          }
          ClassificationsCreativeWork
            .where(
              creative_work_id: to_update_image.id,
              classifications_alias_id: @creative_works_classification_alias_id
            )
            .first_or_initialize
            .set_data(data_classifications_creative_work)
            .save
        end
      end

      def set_primary_image(primaryImage, place_id)
        return if primaryImage.nil? || primaryImage.empty?
        creative_work_image = CreativeWork
          .where(
            "metadata ->> 'external_key' = ? AND external_source_id = ?",
            primaryImage['id'],
            @external_source_id
          )
        if creative_work_image.count > 0
          creative_work_id = creative_work_image.first.id
          to_update_place = Place.where(id: place_id).first
          to_update_place.photo = creative_work_id
          to_update_place.save
        end
      end

      def extract_place_data ( data )
        # prioritize longText over shortText
        description = data.has_key?('shortText') ? data['shortText'].strip : nil
        description = data['longText'].strip if data.has_key?('longText')

        altitude = data.has_key?('altitude') ? data['altitude'] : nil
        lon,lat,_ = data['geometry'].split(/[, ]/,3)
        location = RGeo::Geographic.spherical_factory(srid: 4326).point(lon, lat)
        line = data.has_key?('geometry') ? convert_tour_geometry(data['geometry']) : nil

        address_locality = data.has_key?('address') && data['address'].has_key?('town') ? data['address']['town'].strip : nil
        street_address = set_street_address(data)
        postal_code = data.has_key?('address') && data['address'].has_key?('zipcode') ? data['address']['zipcode'].strip : nil
        address_country = data.has_key?('countryCode') ? data['countryCode'].strip : nil
        fax_number = data.has_key?('fax') ? data['fax'].strip : nil
        telephone = data.has_key?('phone') ? data['phone'].strip : nil
        email = data.has_key?('email') ? data['email'].strip : nil
        url = data.has_key?('homepage') ? data['homepage'].strip : nil
        hours_available = data.has_key?('businessHours') ? data['businessHours'].strip : nil

        return {
          'external_source_id' => @external_source_id,
          'external_key' => data['id'],
          'seen_at' => Time.zone.now,
          'name' => data['title'],
          'description' => description,
          'elevation' => altitude.to_f,
          'longitude' => lon.to_f,
          'latitude' => lat.to_f,
          'location' => location,
          'line' => line,
          'addressLocality' => address_locality,
          'streetAddress' => street_address,
          'postalCode' => postal_code,
          'addressCountry' => address_country,
          'faxNumber' => fax_number,
          'telephone' => telephone,
          'email' => email,
          'url' => url,
          'hoursAvailable' => hours_available
        }
      end

    def set_street_address(data)
      street_address = data.has_key?('address') && data['address'].has_key?('street') ? data['address']['street'].strip : nil
      if !street_address.nil? && data.has_key?('address') && data['address'].has_key?('housenumber')
        if street_address.reverse.to_i == 0 #sometimes the address already includes the housenumber and in addition a housenumber is given
          street_address+=' '+ data['address']['housenumber'].strip
        end
      end
      street_address
    end
    # small helper
      def get_id(object, symbol, value)
        return nil if value.nil?
        result = object.where(external_source_id: @external_source_id, symbol => value).first
        return result.nil? ? nil : result.id
      end

      def convert_bbox(bbox)
        lon1,lat1,lon2,lat2 = bbox.split(/[, ]/)
        factory = RGeo::Geographic.spherical_factory(srid: 4326)
        point1 = factory.point(lon1,lat1)
        point2 = factory.point(lon1,lat2)
        point3 = factory.point(lon2,lat2)
        point4 = factory.point(lon2,lat1)
        line = factory.line_string([point1, point2, point3, point4, point1])
        return factory.polygon(line)
      end

      def convert_tour_geometry(geometry_string)
        geometry = geometry_string.split(" ").map!{|point| point.split(',').map!(&:to_f)}
        factory = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
        geometry_points = geometry.map{|point| factory.point(point[0],point[1],point[2])}
        return factory.line_string(geometry_points)
      end

    # logging ceremony for import logic
      def import_logging
        start_time = Time.zone.now
        @log.info "BEGIN IMPORT : " + start_time.to_s
        @log.info 'OutdoorActive Importer:'
        @log.info "MongoDB: #{DownloadPoi.database_name}"

        save_logger_level = Rails.logger.level
        Rails.logger.level = 4 unless @verbose

        yield

        end_time = Time.zone.now
        @log.info "  total import time: #{(end_time-start_time).round(2)} [s]"
        @log.info 'end'
        @log.info "END IMPORT : " + end_time.to_s

        Rails.logger.level = save_logger_level
      end

      def import_classification_logging (name)
        start_time = Time.zone.now
        @log.info "  importing #{name} into classifications"
        classifications_present = Classification.where(external_source_id: @external_source_id).count
        classifications_groups = ClassificationsGroup.where(external_source_id: @external_source_id).count
        classifications_alias = ClassificationsGroup.joins("INNER JOIN classifications_aliases ON classifications_groups.classifications_alias_id = classifications_aliases.id").count
        classifications_trees_present = ClassificationsTree.where(external_source_id: @external_source_id).count
        downloaded = DownloadCategory.count if name == 'category'
        downloaded = DownloadRegion.count if name == 'region'
        @log.info "  -- before: #{classifications_present}[class.]|#{classifications_groups}[class.group]|#{classifications_alias}[class.alias]|#{classifications_trees_present}[class.tree]"
        @log.info "  -- to import: #{downloaded}"

        yield

        classifications_present = Classification.where(external_source_id: @external_source_id).count
        classifications_groups = ClassificationsGroup.where(external_source_id: @external_source_id).count
        classifications_alias = ClassificationsGroup.joins("INNER JOIN classifications_aliases ON classifications_groups.classifications_alias_id = classifications_aliases.id").count
        classifications_trees_present = ClassificationsTree.where(external_source_id: @external_source_id).count
        downloaded = DownloadCategory.count if name == 'category'
        downloaded = DownloadRegion.count if name == 'region'
        @log.info "  -- after : #{classifications_present}[class.]|#{classifications_groups}[class.group]|#{classifications_alias}[class.alias]|#{classifications_trees_present}[class.tree]"
        @log.info "  -- to import: #{downloaded}"
        end_time = Time.zone.now
        @log.info "  end ( #{(end_time-start_time).round(2)} [s] )"
      end

      def import_poi_logging
        start_time = Time.zone.now
        places_present = Place.where(external_source_id: @external_source_id).count
        places_classifications_present = ClassificationsPlace.where(external_source_id: @external_source_id).count
        pois_imported = DownloadPoi.count
        pois_upsert_imported = DownloadPoiUpsert.count
        #images_present = Image.where(external_source_id: @external_source_id).count
        #images_place_present = ImagesPlace.where(external_source_id: @external_source_id).count
        @log.info "  importing pois into places"
        @log.info "  -- before: Places: #{places_present} / PlacesClassifications: #{places_classifications_present}"
        #@log.info "  -- before: Images: #{images_present} / PlacesImage: #{images_place_present}"
        @log.info "  -- incremental updates/inserts: #{pois_upsert_imported} -- overall downloaded: #{pois_imported}"

        yield

        places_present = Place.where(external_source_id: @external_source_id).count
        places_classifications_present = ClassificationsPlace.where(external_source_id: @external_source_id).count
        #images_present = Image.where(external_source_id: @external_source_id).count
        #images_place_present = ImagesPlace.where(external_source_id: @external_source_id).count
        @log.info "  -- after : Places: #{places_present} / PlacesClassifications: #{places_classifications_present}"
        #@log.info "  -- after : Images: #{images_present} / PlacesImage: #{images_place_present}"
        end_time = Time.zone.now
        @log.info "  end importing pois #{(end_time-start_time).round(2)} [s]"
      end

    end
  end
end
