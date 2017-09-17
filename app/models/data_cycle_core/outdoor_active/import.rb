module DataCycleCore
  module OutdoorActive
    class Import < DataCycleCore::Import::ImportBase
      def import(**options, &block)
        callbacks = DataCycleCore::Callbacks.new(block)

        # categories can only be imported for one single locale
        import_categories(callbacks, **(options || {}).merge({locales: [I18n.default_locale]}))
        # regions can only be imported for one single locale
        import_regions(callbacks, **(options || {}).merge({locales: [I18n.default_locale]}))
      end

      def import_categories(callbacks = DataCycleCore::Callbacks.new, **options)
        import_classifications(
          Category,
          'OutdoorActive - Kategorien',
          ->(locale) { Category.where("dump.#{locale}.parentId": nil) },
          ->(parent_category_data, locale) { Category.where("dump.#{locale}.parentId": parent_category_data['id']) },
          ->(raw_data) {
            DataCycleCore::Classification
              .find_by(external_source_id: external_source.id, external_key: raw_data['parentId'])
              .try(:primary_classification_alias)
          },
          ->(raw_data) {
            {
              external_id: raw_data['id'],
              name: raw_data['name']
            }
          },
          callbacks,
          **options
        )
      end

      def import_regions(callbacks = DataCycleCore::Callbacks.new, **options)
        import_classifications(
          Region,
          'OutdoorActive - Regionen',
          ->(locale) { Region.where("this.dump.#{locale}.id == this.dump.#{locale}.parentId") },
          ->(parent_category_data, locale) {
            Region.where(
              "dump.#{locale}.parentId": parent_category_data['id'],
              "dump.#{locale}.id": {'$ne': parent_category_data['id']}
            )
          },
          ->(raw_data) {
            return nil if raw_data['parentId'] == raw_data['id']

            DataCycleCore::Classification
              .find_by(external_source_id: external_source.id, external_key: raw_data['parentId'])
              .try(:primary_classification_alias)
          },
          ->(raw_data) {
            {
              external_id: raw_data['id'],
              name: raw_data['name']
          },
          callbacks,
          **options
        )
      end
    end

    #
    #   def initialize ( uuid , incremental_update = false, page_size = 300, verbose = false )
    #     @external_source_id = uuid
    #     @download_page_size = page_size
    #     @verbose = verbose
    #     @incremental_update = incremental_update
    #     @log = DataCycleCore::Logger.new('outdooractive_import')
    #     init_db
    #   end
    #
    #   def init_db
    #     @classification_tree_label_id = init_or_create_classification_tree_label('OutdoorActive')
    #     @creative_work_classification_id = init_or_create_classification('Bild')
    #   end
    #
    #   def init_or_create_classification_tree_label(label_string)
    #     classification_tree_label = ClassificationTreeLabel.
    #       find_or_create_by(name: label_string, external_source_id: @external_source_id) do |item|
    #         item.seen_at = Time.zone.now
    #       end
    #     classification_tree_label.id
    #   end
    #
    #   def init_or_create_classification(keyword)
    #     classification = Classification.find_or_create_by(name: keyword, external_source_id: @external_source_id, external_type: "place") do |data_set|
    #       data_set.seen_at = Time.zone.now
    #     end
    #
    #     # check if entries up to classification_tree with label 'OutdoorActive' exist
    #     class_group = ClassificationGroup.
    #       joins(classification_alias: [classification_tree: [:classification_tree_label]]).
    #       where("classification_groups.classification_id = ?", classification.id).
    #       where("classification_trees.external_source_id = ?", @external_source_id).
    #       where("classification_tree_labels.name = ?", 'OutdoorActive')
    #
    #     if class_group.count < 1
    #       classification_alias = ClassificationAlias.create(name: keyword, external_source_id: @external_source_id) do |data_set|
    #         data_set.seen_at = Time.zone.now
    #       end
    #       ClassificationGroup.
    #         find_or_create_by(
    #           classification_id: classification.id,
    #           classification_alias_id: classification_alias.id,
    #           external_source_id: @external_source_id
    #         ) do |data_set|
    #           data_set.seen_at = Time.zone.now
    #       end
    #       ClassificationTree.
    #         find_or_create_by(
    #           classification_alias_id: classification_alias.id,
    #           external_source_id: @external_source_id,
    #           classification_tree_label_id: @classification_tree_label_id,
    #           parent_classification_alias_id: nil
    #         ) do |data_set|
    #           data_set.seen_at = Time.zone.now
    #       end
    #     end
    #     return classification.id
    #   end
    #
    # # main import functionality
    #   def import(options = {})
    #     Mongoid.override_database(nil) #reset to default
    #     Mongoid.override_database("#{DownloadPoi.database_name}_#{@external_source_id}")
    #
    #     import_logging do
    #       import_category
    #       import_region
    #       import_poi(options)
    #     end
    #
    #     Mongoid.override_database(nil) #reset to default
    #   end
    #
    # private
    #
    #   def import_category
    #     import_classification_logging ('category') do
    #       DownloadCategory.all.order_by(:'_id'.asc).each do |loaded_category|
    #         ActiveRecord::Base.transaction do
    #           data_hash = {
    #             'external_source_id' => @external_source_id,
    #             'external_key' => loaded_category.id,
    #             'external_type' => 'category',
    #             'name' => loaded_category.name,
    #             'seen_at' => Time.zone.now
    #           }
    #           upsert_classification_from_key(loaded_category.id, loaded_category.parent_id, data_hash)
    #         end
    #       end
    #     end
    #   end
    #
    #   def import_region
    #     import_classification_logging ('region') do
    #       DownloadRegion.all.each do |load_region|
    #         ActiveRecord::Base.transaction do
    #           bbox = convert_bbox(load_region.bbox)
    #           region_hash = {
    #             'external_source_id' => @external_source_id,
    #             'external_key' => load_region.region_id,
    #             'external_type' => 'region',
    #             'name' => load_region.name,
    #             'description' => load_region.categoryTitle,
    #             'bbox' => bbox,
    #             'seen_at' => Time.zone.now
    #           }
    #           upsert_classification_from_key(load_region.region_id, load_region.parent_id, region_hash)
    #         end
    #       end
    #     end
    #   end
    #
    #   def import_poi(options)
    #     import_poi_logging do
    #
    #       if @incremental_update
    #         query = DownloadPoiUpsert.all
    #       elsif DataCycleCore::OutdoorActive.poi_filter
    #         query = DataCycleCore::OutdoorActive.poi_filter.call(DownloadPoi.all)
    #       else
    #         query = DownloadPoi.all
    #       end
    #
    #       if options[:max_count]
    #         query = query.limit(options[:max_count].to_i)
    #       end
    #
    #       indexes = query.map {|index| index.id }
    #
    #       updates = indexes.count
    #
    #       print " " * 40 + "loading"
    #
    #       page_size = 50 #avoid timeout from Mongo-cursor!!!
    #       pages = updates.fdiv(page_size).ceil
    #       pages.times do |index|
    #         DownloadPoi.in(_id: indexes).extras(:limit => page_size, :skip => (index*page_size)).each do |load_poi|
    #           place_template = poi_template(load_poi)
    #           validation = place_template.metadata['validation']
    #
    #           print '.' if (updates % @download_page_size) == 0
    #           updates-=1
    #           to_update_place = Place
    #             .where(external_source_id: @external_source_id,
    #               external_key: load_poi.id)
    #             .first_or_initialize
    #
    #           if to_update_place.metadata.nil?
    #             to_update_place.metadata = { 'validation' => validation }
    #           else
    #             to_update_place.metadata['validation'] = validation
    #           end
    #           to_update_place.save!
    #
    #           ActiveRecord::Base.transaction do
    #             image = create_creative_work_place( load_poi.dump[load_poi.dump.keys.first]['images'], to_update_place.id )
    #             primaryImage = set_primary_image( load_poi.dump[load_poi.dump.keys.first]['primaryImage'], to_update_place.id )
    #             load_poi.dump.each do |lang, lang_dump|
    #               I18n.with_locale(lang) do
    #                 place_hash = ((to_update_place.get_data_hash || {}) rescue {}).merge(extract_place_data(lang_dump))
    #                 place_hash['primaryImage'] = primaryImage if primaryImage
    #                 place_hash['image'] = image if image.count > 0
    #                 to_update_place.set_data_hash(place_hash)
    #                 to_update_place.save!
    #               end
    #             end
    #             create_classification_place_regions( load_poi.dump[load_poi.dump.keys.first]['regions'], to_update_place.id )
    #             create_classification_place_category( load_poi.dump[load_poi.dump.keys.first]['category'], to_update_place.id )
    #             # create_classification_from_bool( 'winterActivity', load_poi.dump[load_poi.dump.keys.first]['winterActivity'], to_update_place.id )
    #             # create_classification_entry('Jahreszeiten', 'Winter', to_update_place.id) if load_poi.dump[load_poi.dump.keys.first]['winterActivity']
    #             # create_classification_from_string( 'frontendtype', load_poi.dump[load_poi.dump.keys.first]['frontendtype'], to_update_place.id )
    #             # create_classification_entry('Type', load_poi.dump[load_poi.dump.keys.first]['frontendtype'], to_update_place.id) unless load_poi.dump[load_poi.dump.keys.first]['frontendtype'].blank?
    #             # create_classification_from_string( 'source', load_poi.dump[load_poi.dump.keys.first]['meta']['source']['name'], to_update_place.id )
    #             create_classifications_from_array('properties', load_poi.dump[load_poi.dump.keys.first]['properties']['property'], 'text', to_update_place.id) if load_poi.dump[load_poi.dump.keys.first].has_key?('properties')
    #           end
    #         end
    #       end
    #       puts "\n"
    #       DownloadPoiUpsert.delete_all if @incremental_update
    #     end
    #   end
    #
    #   def create_classification_entry(label_name, alias_name, place_id)
    #     classification = DataCycleCore::Classification.where(name: alias_name).
    #       joins(classification_groups: [classification_alias: [classification_tree: [:classification_tree_label]]]).
    #       where('classification_aliases.name = ?', alias_name).
    #       where('classification_tree_labels.name = ?', label_name).
    #       first!
    #
    #     DataCycleCore::ClassificationPlace.find_or_create_by(place_id: place_id, classification_id: classification.id, external_source_id: @external_source_id) do |item|
    #       item.seen_at = Time.zone.now
    #     end
    #   end
    #
    #   def upsert_classification_from_key(external_key, parent_external_key, data_hash)
    #     classification_id = upsert_classification(external_key, data_hash)
    #     unless parent_external_key.nil?
    #       parent_classification = Classification.find_by(external_source_id: @external_source_id, external_key: parent_external_key)
    #
    #       if (parent_classification.nil?)
    #         @log.warn("parent category with external key #{parent_external_key} from data source #{@external_source_id} is missing")
    #         parent_classification_id = nil
    #       else
    #         parent_classification_id = parent_classification.id
    #       end
    #     else
    #       parent_classification_id = nil
    #     end
    #     upsert_classification_from_id(classification_id, parent_classification_id, data_hash)
    #   end
    #
    #   def upsert_classification(external_key, data_hash)
    #     if external_key.nil?
    #       classification = Classification.new
    #     else
    #       classification = Classification
    #         .where(external_source_id: @external_source_id, external_key: external_key)
    #         .first_or_initialize
    #     end
    #     classification.set_data(data_hash).save
    #     return classification.id
    #   end
    #
    #   def upsert_classification_group_alias (classification_id, name)
    #     classification_group = ClassificationGroup
    #       .where(external_source_id: @external_source_id, classification_id: classification_id)
    #       .first_or_initialize
    #     classification_alias_id = classification_group.classification_alias_id
    #
    #     if classification_alias_id.nil?
    #       classification_alias = ClassificationAlias.new
    #       classification_alias.set_data({'name' => name, 'seen_at' => Time.zone.now, 'external_source_id' => @external_source_id}).save
    #       classification_alias_id = classification_alias.id
    #     end
    #     classification_group.set_data({
    #       'classification_id' => classification_id,
    #       'classification_alias_id' => classification_alias_id,
    #       'seen_at' => Time.zone.now
    #     }).save
    #     return classification_alias_id
    #   end
    #
    #   def get_parent_classification_alias_id(parent_external_key)
    #     unless parent_external_key.nil?
    #       parent_classification_id = get_id(Classification, :external_key, parent_external_key)
    #       parent_classification_alias_id = ClassificationGroup
    #         .where(external_source_id: @external_source_id, classification_id: parent_classification_id)
    #         .first
    #         .classification_alias_id
    #     else
    #       parent_classification_alias_id = nil
    #     end
    #     return parent_classification_alias_id
    #   end
    #
    #   def upsert_classification_tree (classification_alias_id, parent_classification_alias_id)
    #     data_tree_hash = {
    #       'external_source_id' => @external_source_id,
    #       'classification_alias_id' => classification_alias_id,
    #       'parent_classification_alias_id' => parent_classification_alias_id,
    #       'seen_at' => Time.zone.now
    #     }
    #     classification_tree = ClassificationTree
    #       .where(
    #         external_source_id: @external_source_id,
    #         classification_alias_id: classification_alias_id,
    #         parent_classification_alias_id: parent_classification_alias_id,
    #         classification_tree_label_id: @classification_tree_label_id
    #       )
    #       .first_or_initialize
    #     classification_tree.set_data(data_tree_hash).save
    #   end
    #
    #   def create_classification_place_regions( regions, place_id)
    #     return if regions.empty? # some records have no associated region
    #     regions['region'].each do |record|
    #       create_classification_place_from_key(record['id'], place_id)
    #     end
    #   end
    #
    #   def create_classification_place_category(category, place_id)
    #     return if category.empty?
    #     create_classification_place_from_key(category['id'], place_id)
    #   end
    #
    #   def create_classification_place_from_key(external_key, place_id)
    #     classification_id = get_id(Classification, :external_key, external_key)
    #     unless classification_id.nil?
    #       create_classification_place(classification_id, place_id)
    #       create_classification_place_for_ancestors(classification_id, place_id)
    #     end
    #   end
    #
    #   def create_classification_place_for_ancestors(classification_id, place_id)
    #     classification_alias = ClassificationAlias
    #       .joins(:classification_groups)
    #       .where("classification_groups.classification_id = ? AND classification_groups.external_source_id= ?", classification_id, @external_source_id)
    #       .first
    #     tree_ancestors = ClassificationTree
    #       .where(
    #         classification_alias_id: classification_alias.id,
    #         external_source_id: @external_source_id,
    #         classification_tree_label_id: @classification_tree_label_id
    #         )
    #         .first
    #         .ancestors
    #     tree_ancestors.each do |tree_entry|
    #       ancestor_classification_alias_id = tree_entry.classification_alias_id
    #       ancestor_classification_id = Classification
    #         .joins(:classification_groups)
    #         .where("classification_groups.classification_alias_id = ? AND classification_groups.external_source_id= ?", ancestor_classification_alias_id, @external_source_id)
    #         .first
    #         .id
    #       create_classification_place(ancestor_classification_id, place_id)
    #     end
    #   end
    #
    #   def create_classification_from_bool(name, value, place_id)
    #     if value == true
    #       classification_id = get_id(Classification, :name, name)
    #       if classification_id.nil?
    #         data_hash = {
    #           'external_source_id' => @external_source_id,
    #           'external_type' => 'bool extracted from POI',
    #           'name' => name,
    #           'seen_at' => Time.zone.now
    #         }
    #         classification_id = upsert_classification_from_id(nil, nil, data_hash)
    #       end
    #       create_classification_place(classification_id, place_id)
    #     end
    #   end
    #
    #   def create_classification_from_string(name, value, place_id)
    #     parent_classification_id = get_id(Classification, :name, name)
    #     if parent_classification_id.nil?
    #       parent_data_hash = {
    #         'external_source_id' => @external_source_id,
    #         'external_type' => 'string extracted from POI',
    #         'name' => name,
    #         'seen_at' => Time.zone.now
    #       }
    #       parent_classification_id = upsert_classification_from_id(nil,nil, parent_data_hash)
    #     end
    #     classification_id = get_id(Classification, :name, value)
    #     if classification_id.nil?
    #       child_data_hash = {
    #         'external_source_id' => @external_source_id,
    #         'external_type' => 'string extracted from POI',
    #         'name' => value,
    #         'seen_at' => Time.zone.now
    #       }
    #       classification_id = upsert_classification_from_id(nil, parent_classification_id, child_data_hash)
    #     end
    #     create_classification_place(parent_classification_id, place_id)
    #     create_classification_place(classification_id, place_id)
    #   end
    #
    #   def create_classifications_from_array(name, array, field_name, place_id)
    #     parent_classification_id = get_id(Classification, :name, name)
    #     if parent_classification_id.nil?
    #       parent_data_hash = {
    #         'external_source_id' => @external_source_id,
    #         'external_type' => 'array_name extracted from POI',
    #         'name' => name,
    #         'seen_at' => Time.zone.now
    #       }
    #       parent_classification_id = upsert_classification_from_id(nil,nil, parent_data_hash)
    #     end
    #     # create_classification_place(parent_classification_id, place_id)
    #     array.each do |item|
    #       if item.has_key?(field_name)
    #         classification_id = get_id(Classification, :name, item[field_name])
    #         if classification_id.nil?
    #           child_data_hash = {
    #             'external_source_id' => @external_source_id,
    #             'external_type' => 'array_item extracted from POI',
    #             'name' => item[field_name],
    #             'seen_at' => Time.zone.now
    #           }
    #           classification_id = upsert_classification_from_id(nil, parent_classification_id, child_data_hash)
    #         end
    #         create_classification_place(classification_id, place_id)
    #       end
    #     end
    #   end
    #
    #   def upsert_classification_from_id(classification_id, parent_classification_id, data_hash)
    #     if classification_id.nil?
    #       classification = Classification.new
    #     else
    #       classification = Classification.find(classification_id)
    #     end
    #     classification.set_data(data_hash).save
    #
    #     classification_alias_id = upsert_classification_group_alias(classification.id, data_hash['name'])
    #     if parent_classification_id.nil?
    #       parent_classification_alias_id = nil
    #     else
    #       parent_classification_alias_id = ClassificationGroup
    #         .find_by(classification_id: parent_classification_id, external_source_id: @external_source_id)
    #         .classification_alias_id
    #     end
    #     upsert_classification_tree(classification_alias_id, parent_classification_alias_id)
    #     return classification.id
    #   end
    #
    #   def create_classification_place(classification_id, place_id)
    #     data_hash = {
    #       'external_source_id' => @external_source_id,
    #       'seen_at' => Time.zone.now,
    #       'place_id' => place_id,
    #       'classification_id' => classification_id
    #     }
    #     to_update_classification_place = ClassificationPlace
    #       .find_or_initialize_by(
    #         external_source_id: @external_source_id,
    #         place_id: place_id,
    #         classification_id: classification_id
    #       )
    #     to_update_classification_place.set_data(data_hash).save!
    #   end
    #
    #   def create_creative_work_place( images, place_id)
    #     return [] if images.nil? || images.empty?
    #     return_images = []
    #
    #     template = DataCycleCore::CreativeWork.find_by(template: true, headline: DataCycleCore.default_image_type)
    #
    #     validation_hash = template.metadata['validation']
    #
    #     images['image'].each do |record|
    #       # save image
    #       author = record['author']
    #       author ||= record['meta']['authorFull']['name'] if record.has_key?('meta') && record['meta'].has_key?('authorFull')
    #       gallery = record['gallery'].blank? ? 'false' : record['gallery'].to_s
    #       data_image = {
    #         'headline' => record['title'],
    #         'url' => "http://img.oastatic.com/img/#{record['id']}",
    #         'contentUrl' => "http://img.oastatic.com/img/#{record['id']}/.jpg",
    #         'thumbnailUrl' => "http://img.oastatic.com/img/400/400/fit/#{record['id']}/.jpg",
    #         'gallery' => gallery,
    #         'seen_at' => Time.zone.now
    #       }
    #       to_update_image = CreativeWork.where(external_key: record['id'], external_source_id: @external_source_id).first_or_initialize
    #       if to_update_image.metadata.blank?
    #         to_update_image.metadata = { 'validation' => validation_hash }
    #       else
    #         to_update_image.metadata['validation'] = validation_hash
    #       end
    #       to_update_image.save!
    #
    #       error = to_update_image.set_data_hash(data_image)
    #       if error[:error].count > 0
    #         ap error[:error]
    #         @log.info "  could not import Image for #{place_id}!"
    #         @log.info "  data given for Image: #{record}"
    #         to_update_image.destroy
    #         next
    #       else
    #         to_update_image.save!
    #         return_images.push(to_update_image.id)
    #       end
    #     end
    #     return_images
    #   end
    #
    #   def set_primary_image(primaryImage, place_id)
    #     return nil if primaryImage.blank?
    #     creative_work_image = CreativeWork.where(external_key: primaryImage['id'], external_source_id: @external_source_id)
    #     creative_work_id = nil
    #     creative_work_id = creative_work_image.first.id if creative_work_image.count > 0
    #   end
    #
    #   def extract_place_data(data)
    #     data.extend attribute_transformer(data)
    #
    #     return Hash[data.to_h.map { |k, v| [k.to_s, v] }].merge({
    #       'external_key' => data['id'],
    #       'external_source_id' => @external_source_id
    #     })
    #   end
    #
    # # small helper
    #   def get_id(object, symbol, value)
    #     return nil if value.nil?
    #     result = object.where(external_source_id: @external_source_id, symbol => value).first
    #     return result.nil? ? nil : result.id
    #   end
    #
    #   def convert_bbox(bbox)
    #     lon1,lat1,lon2,lat2 = bbox.split(/[, ]/)
    #     factory = RGeo::Geographic.spherical_factory(srid: 4326)
    #     point1 = factory.point(lon1,lat1)
    #     point2 = factory.point(lon1,lat2)
    #     point3 = factory.point(lon2,lat2)
    #     point4 = factory.point(lon2,lat1)
    #     line = factory.line_string([point1, point2, point3, point4, point1])
    #     return factory.polygon(line)
    #   end
    #
    # # logging ceremony for import logic
    #   def import_logging
    #     start_time = Time.zone.now
    #     @log.info "BEGIN IMPORT : " + start_time.to_s
    #     @log.info 'OutdoorActive Importer:'
    #     @log.info "MongoDB: #{DownloadPoi.database_name}"
    #
    #     save_logger_level = Rails.logger.level
    #     Rails.logger.level = 4 unless @verbose
    #
    #     yield
    #
    #     end_time = Time.zone.now
    #     @log.info "  total import time: #{(end_time-start_time).round(2)} [s]"
    #     @log.info 'end'
    #     @log.info "END IMPORT : " + end_time.to_s
    #
    #     Rails.logger.level = save_logger_level
    #   end
    #
    #   def import_classification_logging (name)
    #     start_time = Time.zone.now
    #     @log.info "  importing #{name} into classifications"
    #     classifications_present = Classification.where(external_source_id: @external_source_id).count
    #     classification_groups = ClassificationGroup.where(external_source_id: @external_source_id).count
    #     classification_alias = ClassificationGroup.joins("INNER JOIN classification_aliases ON classification_groups.classification_alias_id = classification_aliases.id").count
    #     classification_tree_present = ClassificationTree.where(external_source_id: @external_source_id).count
    #     downloaded = DownloadCategory.count if name == 'category'
    #     downloaded = DownloadRegion.count if name == 'region'
    #     @log.info "  -- before: #{classifications_present}[class.]|#{classification_groups}[class.group]|#{classification_alias}[class.alias]|#{classification_tree_present}[class.tree]"
    #     @log.info "  -- to import: #{downloaded}"
    #
    #     yield
    #
    #     classifications_present = Classification.where(external_source_id: @external_source_id).count
    #     classification_groups = ClassificationGroup.where(external_source_id: @external_source_id).count
    #     classification_alias = ClassificationGroup.joins("INNER JOIN classification_aliases ON classification_groups.classification_alias_id = classification_aliases.id").count
    #     classification_tree_present = ClassificationTree.where(external_source_id: @external_source_id).count
    #     downloaded = DownloadCategory.count if name == 'category'
    #     downloaded = DownloadRegion.count if name == 'region'
    #     @log.info "  -- after : #{classifications_present}[class.]|#{classification_groups}[class.group]|#{classification_alias}[class.alias]|#{classification_tree_present}[class.tree]"
    #     @log.info "  -- to import: #{downloaded}"
    #     end_time = Time.zone.now
    #     @log.info "  end ( #{(end_time-start_time).round(2)} [s] )"
    #   end
    #
    #   def import_poi_logging
    #     start_time = Time.zone.now
    #     places_present = Place.where(external_source_id: @external_source_id).count
    #     places_classifications_present = ClassificationPlace.where(external_source_id: @external_source_id).count
    #     pois_imported = DownloadPoi.count
    #     pois_upsert_imported = DownloadPoiUpsert.count
    #     #images_present = Image.where(external_source_id: @external_source_id).count
    #     #images_place_present = ImagesPlace.where(external_source_id: @external_source_id).count
    #     @log.info "  importing pois into places"
    #     @log.info "  -- before: Places: #{places_present} / PlacesClassifications: #{places_classifications_present}"
    #     #@log.info "  -- before: Images: #{images_present} / PlacesImage: #{images_place_present}"
    #     @log.info "  -- incremental updates/inserts: #{pois_upsert_imported} -- overall downloaded: #{pois_imported}"
    #
    #     yield
    #
    #     places_present = Place.where(external_source_id: @external_source_id).count
    #     places_classifications_present = ClassificationPlace.where(external_source_id: @external_source_id).count
    #     #images_present = Image.where(external_source_id: @external_source_id).count
    #     #images_place_present = ImagesPlace.where(external_source_id: @external_source_id).count
    #     @log.info "  -- after : Places: #{places_present} / PlacesClassifications: #{places_classifications_present}"
    #     #@log.info "  -- after : Images: #{images_present} / PlacesImage: #{images_place_present}"
    #     end_time = Time.zone.now
    #     @log.info "  end importing pois #{(end_time-start_time).round(2)} [s]"
    #   end
    #
    #
    #   private
    #
    #   def poi_template(raw_data)
    #     if DataCycleCore::OutdoorActive.poi_template.nil?
    #       @log.error 'Missing configuration for poi template to use when importing pois from outdoor active'
    #       raise 'Missing configuration for poi template'
    #     elsif DataCycleCore::OutdoorActive.poi_template.is_a? String
    #       begin
    #         Place.find_by!(template: true, headline: DataCycleCore::OutdoorActive.poi_template)
    #       rescue ActiveRecord::RecordNotFound => e
    #         @log.error "Missing template '#{DataCycleCore::OutdoorActive.poi_template}' for places"
    #         raise e
    #       end
    #     elsif DataCycleCore::OutdoorActive.poi_template.is_a? Proc
    #       begin
    #         Place.find_by!(template: true, headline: DataCycleCore::OutdoorActive.poi_template.call(raw_data))
    #       rescue ActiveRecord::RecordNotFound => e
    #         @log.error "Missing template '#{DataCycleCore::OutdoorActive.poi_template.call(raw_data)}' for places"
    #         raise e
    #       end
    #     else
    #       raise NotImplementedError
    #     end
    #   end
    #
    #   def attribute_transformer(raw_data)
    #     if raw_data['frontendtype'] == 'poi'
    #       PoiAttributeTransformation
    #     elsif raw_data['frontendtype'] == 'tour'
    #       TourAttributeTransformation
    #     else
    #       PoiAttributeTransformation
    #     end
    #   end
    # end
  end
end
