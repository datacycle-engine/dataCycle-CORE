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

        def self.import_local_shape(utility_object:, options:, credentials:)
          local_dirs = Array(credentials.dig('directory'))
          geometry_type = options.dig(:import, :geometry_type).constantize
          srid = options.dig(:import, :srid).to_i
          db_table = options.dig(:import, :db_table)
          tree_label = options.dig(:import, :tree_label)
          external_source_id = options.dig(:external_source_id)

          local_dirs.each do |ld|
            raise "Directory: #{ld} does not exist" unless File.directory?(ld)
          end
          raise 'Unkown asset type or local dir' unless local_dirs.present? && geometry_type.present?

          init_logging(utility_object) do |logging|
            phase_name = utility_object.source_type.collection_name
            logging.preparing_phase("#{utility_object.external_source.name} #{phase_name}")
            item_count = 0
            begin
              durations = []

              Dir.glob(local_dirs.map { |ld| File.join(File.expand_path(ld), '*.shp') }).each do |shapefile|
                durations << Benchmark.realtime do
                  logging.phase_started(shapefile)
                  classifications_array = []
                  polygon_count = 0

                  RGeo::Shapefile::Reader.open(shapefile, { srid: srid }) do |file|
                    file.each do |record|
                      attributes = record.attributes

                      classification_polygon = geometry_type.new(admin_level: attributes['adminlevel'], geom: record.geometry)
                      next unless classification_polygon.save

                      uri = attributes['wikidata'].blank? ? '' : 'https://www.wikidata.org/wiki/' + attributes['wikidata']

                      classifications_array.push({ classification_polygon_id: classification_polygon[:id], external_key: attributes['id'], adminlevel: attributes['adminlevel'], name: attributes['locname'], parent_external_key: attributes['parent_id'], external_source_id: external_source_id, tree_name: tree_label, uri: uri })

                      polygon_count += 1
                    end
                  end
                  logging.info("Imported #{polygon_count} items", '')

                  classifications_array.sort_by! { |classification| classification[:adminlevel] }

                  classifications_array.each do |classification|
                    # polygons without parent are moved to their own classification 'uncategorized'
                    if classification[:parent_external_key].zero? && classification[:adminlevel] > 2
                      pc = classifications_array.detect { |f| f[:adminlevel] == 2 }

                      uncategorized_classification = { external_key: pc[:external_key].to_s + '_uncategorized', adminlevel: 4, name: 'Nicht zugeordnet', parent_external_key: pc[:external_key], external_source_id: pc[:external_source_id], tree_name: pc[:tree_name], uri: pc[:uri] }

                      import_classification(classification_data: uncategorized_classification, parent_external_key: uncategorized_classification[:parent_external_key])
                      classification[:parent_external_key] = uncategorized_classification[:external_key]
                    end

                    classification_alias = import_classification(classification_data: classification, parent_external_key: classification[:parent_external_key])
                    classification_polygon = DataCycleCore::ClassificationPolygon.find(classification[:classification_polygon_id])
                    classification_polygon.classification_alias_id = classification_alias.id
                    classification_polygon.save!
                  end
                  item_count += 1
                end
                break if options[:max_count].present? && item_count >= options[:max_count]
                logging.info('Created Classification', "Duration: #{durations.sum.round(6)} seconds")
              end

              # Vacuum Analyze to update the index on the spatial table
              unless db_table.nil?
                logging.info("Start VACCUM ANALYZE #{db_table}", '')

                quoted_table = ActiveRecord::Base.connection.quote_column_name(db_table)
                ActiveRecord::Base.connection.execute("VACUUM ANALYZE #{quoted_table}")
              end

              GC.start
            ensure
              logging.phase_finished(phase_name.to_s, item_count)
            end
          end
        end

        def self.init_logging(utility_object, &block)
          DataCycleCore::Generic::Common::ImportFunctions.init_logging(utility_object, &block)
        end

        def self.import_classification(classification_data:, parent_external_key:)
          parent_classification_alias = parent_external_key ? DataCycleCore::ClassificationAlias.includes(:primary_classification, classification_tree: [:classification_tree_label]).find_by(classification_trees: { classification_tree_labels: { name: classification_data[:tree_name] } }, classifications: { external_key: parent_external_key }) : nil

          classification = DataCycleCore::Classification.includes(primary_classification_alias: [classification_tree: :classification_tree_label]).where(external_key: classification_data[:external_key], primary_classification_alias: { classification_trees: { classification_tree_labels: { name: classification_data[:tree_name] } } }).first_or_initialize do |c|
            c.name = classification_data[:name]
            c.description = classification_data[:description] if classification_data[:description].present?
            c.external_key = classification_data[:external_key]
            c.external_source_id = classification_data[:external_source_id]
            c.uri = classification_data[:uri]
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
      end
    end
  end
end
