# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GeoShape
      module Import
        def self.import_data(utility_object:, options:)
          credentials = utility_object.external_source.credentials
          # other remote storage types
          # ftp, sftp, etc.
          raise 'Not implemented' unless credentials.dig('storage_type') == 'local'

          import_local_shape(utility_object: utility_object, options: options, credentials: credentials)
        end

        # it should open files from a directory
        def self.import_local_shape(utility_object:, options:, credentials:)
          local_dirs = Array(credentials.dig('directory'))
          # get asset type from config (new asset type for shape/geojson?)
          geometry_type = options.dig(:import, :geometry_type).constantize
          srid = options.dig(:import, :srid).to_i
          tree_label = options.dig(:import, :tree_label)
          # binding.pry
          external_source_id = utility_object.external_source.id

          local_dirs.each do |ld|
            raise "Directory: #{ld} does not exist" unless File.directory?(ld)
          end
          raise 'Unkown asset type or local dir' unless local_dirs.present? && geometry_type.present?

          init_logging(utility_object) do |logging|
            # binding.pry
            phase_name = utility_object.source_type.collection_name
            # phase_name = 'shape_import'
            logging.preparing_phase("#{utility_object.external_source.name} #{phase_name}")
            item_count = 0
            # tags_attribute_name = options.dig(:import, :extract_tags, :attribute_name) || 'tags'
            begin
              logging.phase_started(phase_name.to_s)
              durations = []

              # loop through dirs and open files
              Dir.glob(local_dirs.map { |ld| File.join(File.expand_path(ld), '*.shp') }).each do |shapefile|
                durations << Benchmark.realtime do
                  # binding.pry
                  logging.info(shapefile, '')
                  classifications_array = []

                  # it should read the content of the files ordered(ASC) by adminlevel row by row
                  RGeo::Shapefile::Reader.open(shapefile, { srid: srid }) do |file|
                    # binding.pry
                    item_count = 0

                    file.each do |record|
                      attributes = record.attributes

                      # binding.pry
                      classification_polygon = geometry_type.new(admin_level: attributes['adminlevel'], geom: record.geometry)
                      next unless classification_polygon.save
                      # binding.pry
                      # poly_id = create_classification_polygon(record.geometry)
                      # classifications_array.push(relation_id, name, external_source_id.from_config, poly_id)
                      classifications_array.push({ classification_polygon_id: classification_polygon[:id], external_key: attributes['id'], adminlevel: attributes['adminlevel'], name: attributes['locname'], parent_external_key: attributes['parent_id'], external_source_id: external_source_id, tree_name: tree_label })

                      item_count += 1
                    end
                  end

                  logging.info("Imported #{item_count} items", "Duration: #{durations.sum.round(6)} seconds")

                  # binding.pry
                  # sort array and loop
                  classifications_array.sort_by! { |classification| classification[:adminlevel] }

                  classifications_array.each do |classification|
                    # for now we ignore polygons without parent
                    # TODO: move polygons without parent in their own parent
                    # binding.pry
                    next if classification[:parent_external_key].zero? && classification[:adminlevel] > 2

                    classification_alias = import_classification(classification_data: classification, parent_external_key: classification[:parent_external_key])
                    # binding.pry
                    classification_polygon = DataCycleCore::ClassificationPolygon.find(classification[:classification_polygon_id])
                    # binding.pry
                    classification_polygon.classification_alias_id = classification_alias.id
                    classification_polygon.save!
                  end

                  logging.info('Created Classification', "Duration: #{durations.sum.round(6)} seconds")

                  # create classification and add FK to class_poly

                  # file = File.open(p)
                  # title = File.basename(file, '.*')

                  # ## process DataCycleImage
                  # # write data to database e.g. DataCycleCore::ClassificationPolygon
                  # asset_file = geometry_type.new(file: file)
                  # next unless asset_file.save

                  # image_data = {
                  #   'name' => title,
                  #   'asset' => asset_file.id
                  # }

                  # # get tags from filename
                  # if options.dig(:import, :tags_from_folders) || options.dig(:import, :extract_tags, :mode) == 'folder'
                  #   image_data[tags_attribute_name] = Pathname(File.dirname(p).gsub(Regexp.union(local_dirs.map { |ld| File.expand_path(ld) }), '')).each_filename.to_a
                  # elsif options.dig(:import, :extract_tags, :mode) == 'filename' && options.dig(:import, :extract_tags, :delimiter).present?
                  #   image_data[tags_attribute_name] = title.split(options.dig(:import, :extract_tags, :delimiter)).slice(0..-2)
                  # end

                  # # process tags + create classification
                  # if image_data.dig(tags_attribute_name).present?
                  #   process_tags(
                  #     raw_data: image_data,
                  #     options: { import: options.dig(:import, :extract_tags)&.deep_symbolize_keys }
                  #   )
                  # end

                  # new_object = process_content(utility_object: utility_object, raw_data: image_data, options: options)
                  # next unless new_object
                  # File.delete(p) if credentials.dig('delete')

                  item_count += 1
                end
                break if options[:max_count].present? && item_count >= options[:max_count]

              # rescue MiniMagick::Error => e
              #   logging.error('MiniMagick::Error', p, nil, e)
              end

              GC.start
              # logging.info("Imported #{item_count} items", "Duration: #{durations.sum.round(6)} seconds")
            ensure
              logging.phase_finished(phase_name.to_s, item_count)
            end
          end
        end

        # def self.process_content(utility_object:, raw_data:, options:)
        #   config = options.dig(:import, :transformations, :asset)
        #   template = config&.dig(:template) || 'Bild'
        #   tags_tree_label = options.dig(:import, :extract_tags, :tree_label) || 'Tags'
        #   tags_attribute_name = options.dig(:import, :extract_tags, :attribute_name) || 'tags'
        #   transformation = DataCycleCore::Generic::DataCycleMedia::Transformations.file_to_asset(tags_tree_label, tags_attribute_name)

        #   DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
        #     utility_object: utility_object,
        #     template: DataCycleCore::Generic::Common::ImportFunctions.load_template(template),
        #     data: DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
        #       config,
        #       transformation.call(raw_data)
        #     ).with_indifferent_access,
        #     local: true
        #   )
        # end

        def self.init_logging(utility_object, &block)
          DataCycleCore::Generic::Common::ImportFunctions.init_logging(utility_object, &block)
        end

        # def self.process_tags(raw_data:, options:)
        #   tree_label = options.dig(:import, :tree_label) || 'Tags'
        #   attribute_name = options.dig(:import, :attribute_name) || 'tags'
        #   keywords = DataCycleCore::Generic::Common::ImportTags.unwind_project_data(
        #     raw_data,
        #     [attribute_name],
        #     [],
        #     []
        #   )
        #   keywords = DataCycleCore::Generic::Common::ImportTags.unwind_project_data(record_data,['tags'],[],[])
        #   return if keywords&.compact.blank?

        #   keywords.each do |keyword_hash|
        #     classification_data = DataCycleCore::Generic::Common::ImportTags.extract_data(options, keyword_hash).merge(tree_name: tree_label)
        #     import_classification(
        #       classification_data: classification_data
        #     )
        #   end
        # end

        def self.import_classification(classification_data:, parent_external_key:)
          # binding.pry
          parent_classification_alias = parent_external_key ? DataCycleCore::ClassificationAlias.includes(:primary_classification, classification_tree: [:classification_tree_label]).find_by(classification_trees: { classification_tree_labels: { name: classification_data[:tree_name] } }, classifications: { external_key: parent_external_key }) : nil

          # TODO: if no parent and adminlevel > 2 create or add to "Other Admin_levels"

          classification = DataCycleCore::Classification.includes(primary_classification_alias: [classification_tree: :classification_tree_label]).where(external_key: classification_data[:external_key], primary_classification_alias: { classification_trees: { classification_tree_labels: { name: classification_data[:tree_name] } } }).first_or_initialize do |c|
            c.name = classification_data[:name]
            c.description = classification_data[:description] if classification_data[:description].present?
            c.external_key = classification_data[:external_key]
            c.external_source_id = classification_data[:external_source_id]
          end

          if classification.new_record?
            classification_alias = DataCycleCore::ClassificationAlias.create!(
              name: classification_data[:name],
              description: classification_data[:description]
            )

            DataCycleCore::ClassificationGroup.create!(
              classification: classification,
              classification_alias: classification_alias
            )

            tree_label = DataCycleCore::ClassificationTreeLabel.find_or_create_by(
              name: classification_data[:tree_name]
            ) do |item|
              item.visibility = DataCycleCore.default_classification_visibilities
            end

            DataCycleCore::ClassificationTree.create!(
              {
                classification_tree_label: tree_label,
                parent_classification_alias: parent_classification_alias,
                sub_classification_alias: classification_alias
              }
            )
          else
            primary_classification_alias = classification.primary_classification_alias
            primary_classification_alias.name = classification_data[:name]
            primary_classification_alias.description = classification_data[:description] if classification_data[:description].present?
            primary_classification_alias.save!

            classification_tree = primary_classification_alias.classification_tree
            classification_tree.parent_classification_alias = parent_classification_alias
            classification_tree.save!

            classification_alias = primary_classification_alias
          end
          classification.save!
          classification_alias
        end

        


          # it should search for a parent classification if attribute.parent_id is present and return the classification_alias corresponding to the found external_key

          # it should create a classification under the right tree (what if no parent_id, but AL>2) and return the classification_alias

          # it should save the geometry of the row in the boundaries-table and add the classification_alias
      end
    end
  end
end
