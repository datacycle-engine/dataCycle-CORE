# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GeoShape
      module ImportWithClassificationPath
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
          external_source_id = options.dig(:external_source_id)
          tree_label = tree_label_for_name(options.dig(:import, :tree_label))
          classification_path_key = options.dig(:import, :classification_path, :key)
          classification_path_seperator = options.dig(:import, :classification_path, :seperator) || '|'

          local_dirs.each do |ld|
            raise "Directory: #{ld} does not exist" unless File.directory?(ld)
          end
          raise 'Unkown asset type or local dir' unless local_dirs.present? && geometry_type.present?
          raise 'Unkown classification_alias key' if classification_path_key.blank?

          init_logging(utility_object) do |logging|
            phase_name = utility_object.source_type.collection_name
            logging.preparing_phase("#{utility_object.external_source.name} #{phase_name}")
            item_count = 0
            begin
              durations = []

              Dir.glob(local_dirs.map { |ld| File.join(File.expand_path(ld), '*.shp') }).each do |shapefile|
                durations << Benchmark.realtime do
                  logging.phase_started(shapefile)
                  polygon_count = 0

                  RGeo::Shapefile::Reader.open(shapefile, { srid: srid }) do |file|
                    file.each do |record|
                      attributes = record.attributes

                      classification_polygon = geometry_type.new(admin_level: attributes['adminlevel'], geom: record.geometry)
                      next unless classification_polygon.save

                      uri = attributes['wikidata'].blank? ? '' : 'https://www.wikidata.org/wiki/' + attributes['wikidata']

                      classification = {
                        external_key: attributes['id'],
                        external_source_id: external_source_id,
                        name: attributes['locname'],
                        uri: uri
                      }.compact_blank!

                      attributes[classification_path_key] = 'Nicht zugeordnet' if attributes.dig(classification_path_key).blank?

                      classification_path = attributes.dig(classification_path_key).split(classification_path_seperator)&.map { |item| { name: item } }
                      classification_path[classification_path.length - 1] = classification
                      classification_alias = tree_label&.create_or_update_classification_alias_by_name(*Array.wrap(classification_path))

                      classification_polygon.classification_alias_id = classification_alias.id
                      classification_polygon.save!

                      polygon_count += 1
                    end
                  end
                  logging.info("Imported #{polygon_count} items", '')
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

        def self.tree_label_for_name(name = nil)
          return if name.blank?
          DataCycleCore::ClassificationTreeLabel.find_or_create_by(
            name: name
          ) do |item|
            item.visibility = DataCycleCore.default_classification_visibilities
          end
        end
      end
    end
  end
end
