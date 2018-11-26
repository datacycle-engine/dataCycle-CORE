# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DataCycleMedia
      module ImportAssets
        def self.import_data(utility_object:, options:)
          credentials = utility_object.external_source.credentials
          # other remote storage types
          # ftp, sftp, etc.
          raise 'Not implemented' unless credentials.dig('storage_type') == 'local'

          import_local_asset(utility_object: utility_object, options: options, credentials: credentials)
        end

        def self.import_local_asset(utility_object:, options:, credentials:)
          local_dir = credentials.dig('directory')
          asset_type = options.dig(:import, :asset_type).constantize

          raise "Directory: #{local_dir} does not exist" unless File.directory?(local_dir)
          raise 'Unkown asset type or local dir' unless local_dir.present? && asset_type.present?

          init_logging(utility_object) do |logging|
            phase_name = utility_object.source_type.collection_name
            logging.preparing_phase("#{utility_object.external_source.name} #{phase_name}")
            item_count = 0
            begin
              logging.phase_started(phase_name.to_s)
              durations = []

              Dir[File.join(File.expand_path(local_dir), '**', '*')].each do |p|
                durations << Benchmark.realtime do
                  file = File.open(p)
                  title = File.basename(file, '.*')

                  ### process DataCycleImage
                  asset_file = asset_type.new(file: file)
                  next unless asset_file.save

                  image_data = {
                    name: title,
                    asset: asset_file.id
                  }
                  new_object = process_content(utility_object: utility_object, raw_data: image_data, options: options)
                  next unless new_object
                  File.delete(p) if credentials.dig('delete')
                  item_count += 1
                end
                break if options[:max_count].present? && item_count >= options[:max_count]
              end

              GC.start
              logging.info("Imported #{item_count} items", "Duration: #{durations.sum.round(6)} seconds")
            ensure
              logging.phase_finished(phase_name.to_s, item_count)
            end
          end
        end

        def self.process_content(utility_object:, raw_data:, options:)
          config = options.dig(:import, :transformations, :asset)
          template = config&.dig(:template) || 'DataCycle - Bild'

          DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
            utility_object: utility_object,
            template: DataCycleCore::Generic::Common::ImportFunctions.load_template(template),
            data: DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
              config,
              raw_data
            ).with_indifferent_access,
            local: true
          )
        end

        def self.init_logging(utility_object, &block)
          DataCycleCore::Generic::Common::ImportFunctions.init_logging(utility_object, &block)
        end
      end
    end
  end
end
