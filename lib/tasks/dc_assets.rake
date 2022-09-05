# frozen_string_literal: true

require 'mini_exiftool_vendored'

namespace :dc do
  namespace :assets do
    namespace :images do
      desc 'Optimize all Images'
      task optimize: :environment do
        logger = Logger.new('log/optimize_images.log')
        temp = Time.zone.now

        image_optim = ::ImageOptim.new(DataCycleCore::Feature::ImageOptimizer.config)
        base = Rails.public_path.join('uploads', 'data_cycle_core', 'image', 'file')

        images = Dir.glob("#{base}/**/{#{DataCycleCore::Feature::ImageOptimizer.version_regex}}*.*")
        items_count = images.size
        return if items_count.zero?

        logger.info("Started optimizing #{items_count} images...")
        puts "START OPTIMIZING ==> Images (#{items_count})"

        progressbar = ProgressBar.create(total: items_count, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

        image_optim.optimize_images!(images) do |unoptimized, optimized|
          progressbar.increment

          logger.info("#{unoptimized} => #{optimized}") if optimized
        end
        puts 'END'
        puts "--> OPTIMIZING time: #{((Time.zone.now - temp) / 60).to_i} min"
      end

      desc 'Update Images file size'
      task update_file_size: :environment do
        temp = Time.zone.now

        assets = DataCycleCore::Image.where(file_size: 0)
        items_count = assets.size
        return if items_count.zero?

        puts "START UPDATE FILE SIZE ==> Images (#{items_count})"

        progressbar = ProgressBar.create(total: items_count, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

        assets.each do |asset|
          progressbar.increment
          asset.file_size = asset.file.size || asset.file.file.size
          asset.save!
        end

        puts 'END'
        puts "--> ELAPSED TIME: #{((Time.zone.now - temp) / 60).to_i} min"
      end

      desc 'Update metadata with exif-tool gem'
      task update_meta_data: :environment do
        temp = Time.zone.now

        assets = DataCycleCore::Image.where("metadata ? 'version'")

        items_count = assets.size

        puts "START UPDATE MetaData ==> Images (#{items_count})"

        progressbar = ProgressBar.create(total: items_count, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

        assets.each do |asset|
          progressbar.increment
          exif_data = MiniExiftool.new(asset.original.file.file, { replace_invalid_chars: true })
          asset.metadata = exif_data
            .to_hash
            .transform_values { |value| value.is_a?(String) ? value.delete("\u0000") : value }
          asset.save!
        rescue StandardError => e
          puts "Error: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
        end

        puts 'END'
        puts "--> ELAPSED TIME: #{((Time.zone.now - temp) / 60).to_i} min"
      end

      desc 'migrate image names by stored_filter'
      task :migrate_image_names_by_stored_filter, [:stored_filter] => [:environment] do |_, args|
        filter_param = args.fetch(:stored_filter, nil)
        abort('A stored filter ID, or a stored filter Name has to be specified') if filter_param.blank?

        temp = Time.zone.now
        stored_filter = DataCycleCore::StoredFilter.find(filter_param)
        query = stored_filter.apply
        images = query.all
        items_count = images.size

        puts "START UPDATE name ==> Images (#{items_count})"

        progressbar = ProgressBar.create(total: items_count, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

        exif_property_names = ['license_classification', 'keyword_classifications', 'copyright_holder', 'author']
        properties = images.first.default_value_property_names.select { |k| exif_property_names.include?(k) }

        images.each do |image|
          progressbar.increment
          data_hash = image.get_data_hash
          update_hash = {}
          properties.each do |property_name, property_definition|
            update_hash[property_name] = DataCycleCore::Utility::DefaultValue::Base.default_values(property_name, property_definition, data_hash, image)
          end
          update_hash['name'] = image.asset.metadata['Headline'] if image.asset.metadata.dig('Headline').present?
          image.available_locales.each do |locale|
            I18n.with_locale(locale) { image.set_data_hash(data_hash: update_hash) }
          end
        end

        puts 'END'
        puts "--> ELAPSED TIME: #{((Time.zone.now - temp) / 60).to_i} min"
      end
    end

    desc 'migrate assets to active_storage'
    task migrate_assets_to_active_storage: :environment do
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:assets:migrate_videos_to_active_storage"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:assets:migrate_pdfs_to_active_storage"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:assets:migrate_audio_to_active_storage"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:assets:migrate_data_cycle_file_to_active_storage"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:assets:migrate_text_file_to_active_storage"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:assets:migrate_srt_file_to_active_storage"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:assets:migrate_images_to_active_storage"].invoke

      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:update_data:computed_attributes"].invoke('PDF', 'false')
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:update_data:computed_attributes"].reenable
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:update_data:computed_attributes"].invoke('Video', 'false')
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:update_data:computed_attributes"].reenable
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:update_data:computed_attributes"].invoke('Audio', 'false')
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:update_data:computed_attributes"].reenable
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:update_data:computed_attributes"].invoke('Bild', 'false')
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:update_data:computed_attributes"].reenable
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:update_data:computed_attributes"].invoke('ImageVariant', 'false')
    end

    desc 'migrate images to active_storage'
    task migrate_images_to_active_storage: :environment do
      temp = Time.zone.now

      assets = DataCycleCore::Image.where.not(file: nil)
      items_count = assets.size
      puts "START MIGRATE IMAGES ==> Image (#{items_count})"

      progressbar = ProgressBar.create(total: items_count, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

      assets.each do |asset|
        progressbar.increment
        begin
          file_path = Rails.public_path.join('uploads', 'data_cycle_core', 'image', 'file', asset[:id], asset[:file])
          asset.file.attach(io: File.open(file_path.to_s), filename: asset[:file])
          asset[:file] = nil
          asset.save
        rescue StandardError => e
          puts "### UnprocessableEntity: Asset: #{asset.id} (#{e})"
        end
      end

      puts 'END'
      puts "--> ELAPSED TIME: #{((Time.zone.now - temp) / 60).to_i} min"
    end

    desc 'migrate videos to active_storage'
    task migrate_videos_to_active_storage: :environment do
      temp = Time.zone.now

      assets = DataCycleCore::Video.where.not(file: nil)
      items_count = assets.size
      puts "START MIGRATE VIDEOS ==> Video (#{items_count})"

      progressbar = ProgressBar.create(total: items_count, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

      assets.each do |asset|
        progressbar.increment
        begin
          file_path = Rails.public_path.join('uploads', 'data_cycle_core', 'video', 'file', asset[:id], asset[:file])
          asset.file.attach(io: File.open(file_path.to_s), filename: asset[:file])
          asset[:file] = nil
          asset.save
        rescue StandardError => e
          puts "### UnprocessableEntity: Asset: #{asset.id} (#{e})"
        end
      end

      puts 'END'
      puts "--> ELAPSED TIME: #{((Time.zone.now - temp) / 60).to_i} min"
    end

    desc 'migrate pdfs to active_storage'
    task migrate_pdfs_to_active_storage: :environment do
      temp = Time.zone.now

      assets = DataCycleCore::Pdf.where.not(file: nil)
      items_count = assets.size
      puts "START MIGRATE PDFS ==> Pdf (#{items_count})"

      progressbar = ProgressBar.create(total: items_count, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

      assets.each do |asset|
        progressbar.increment
        begin
          file_path = Rails.public_path.join('uploads', 'data_cycle_core', 'pdf', 'file', asset[:id], asset[:file])
          asset.file.attach(io: File.open(file_path.to_s), filename: asset[:file])
          asset[:file] = nil
          asset.save
        rescue StandardError => e
          puts "### UnprocessableEntity: Asset: #{asset.id} (#{e})"
        end
      end

      puts 'END'
      puts "--> ELAPSED TIME: #{((Time.zone.now - temp) / 60).to_i} min"
    end

    desc 'migrate audio to active_storage'
    task migrate_audio_to_active_storage: :environment do
      temp = Time.zone.now

      assets = DataCycleCore::Audio.where.not(file: nil)
      items_count = assets.size
      puts "START MIGRATE AUDIO ==> Audio (#{items_count})"

      progressbar = ProgressBar.create(total: items_count, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

      assets.each do |asset|
        progressbar.increment
        begin
          file_path = Rails.public_path.join('uploads', 'data_cycle_core', 'audio', 'file', asset[:id], asset[:file])
          asset.file.attach(io: File.open(file_path.to_s), filename: asset[:file])
          asset[:file] = nil
          asset.save
        rescue StandardError => e
          puts "### UnprocessableEntity: Asset: #{asset.id} (#{e})"
        end
      end

      puts 'END'
      puts "--> ELAPSED TIME: #{((Time.zone.now - temp) / 60).to_i} min"
    end

    desc 'migrate data_cycle_file to active_storage'
    task migrate_data_cycle_file_to_active_storage: :environment do
      temp = Time.zone.now

      assets = DataCycleCore::DataCycleFile.where.not(file: nil)
      items_count = assets.size
      puts "START MIGRATE DataCycleFile ==> DataCycleFile (#{items_count})"

      progressbar = ProgressBar.create(total: items_count, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

      assets.each do |asset|
        progressbar.increment
        begin
          file_path = Rails.public_path.join('uploads', 'data_cycle_core', 'data_cycle_file', 'file', asset[:id], asset[:file])
          asset.file.attach(io: File.open(file_path.to_s), filename: asset[:file])
          asset[:file] = nil
          asset.save
        rescue StandardError => e
          puts "### UnprocessableEntity: Asset: #{asset.id} (#{e})"
        end
      end

      puts 'END'
      puts "--> ELAPSED TIME: #{((Time.zone.now - temp) / 60).to_i} min"
    end

    desc 'migrate text_file to active_storage'
    task migrate_text_file_to_active_storage: :environment do
      temp = Time.zone.now

      assets = DataCycleCore::TextFile.where.not(file: nil)
      items_count = assets.size
      puts "START MIGRATE TextFile ==> TextFile (#{items_count})"

      progressbar = ProgressBar.create(total: items_count, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

      assets.each do |asset|
        progressbar.increment
        begin
          file_path = Rails.public_path.join('uploads', 'data_cycle_core', 'text_file', 'file', asset[:id], asset[:file])
          asset.file.attach(io: File.open(file_path.to_s), filename: asset[:file])
          asset[:file] = nil
          asset.save
        rescue StandardError => e
          puts "### UnprocessableEntity: Asset: #{asset.id} (#{e})"
        end
      end

      puts 'END'
      puts "--> ELAPSED TIME: #{((Time.zone.now - temp) / 60).to_i} min"
    end

    desc 'migrate srt_file to active_storage'
    task migrate_srt_file_to_active_storage: :environment do
      temp = Time.zone.now

      assets = DataCycleCore::SrtFile.where.not(file: nil)
      items_count = assets.size
      puts "START MIGRATE srt_file ==> srt_file (#{items_count})"

      progressbar = ProgressBar.create(total: items_count, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

      assets.each do |asset|
        progressbar.increment
        begin
          file_path = Rails.public_path.join('uploads', 'data_cycle_core', 'srt_file', 'file', asset[:id], asset[:file])
          asset.file.attach(io: File.open(file_path.to_s), filename: asset[:file])
          asset[:file] = nil
          asset.save
        rescue StandardError => e
          puts "### UnprocessableEntity: Asset: #{asset.id} (#{e})"
        end
      end

      puts 'END'
      puts "--> ELAPSED TIME: #{((Time.zone.now - temp) / 60).to_i} min"
    end
  end
end
