# frozen_string_literal: true

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
        index = 0
        items_count = images.size
        return if items_count.zero?

        logger.info("Started optimizing #{items_count} images...")
        puts "START OPTIMIZING ==> Images (#{items_count})"

        image_optim.optimize_images!(images) do |unoptimized, optimized|
          # progress bar
          if items_count > 49
            if (index % (items_count / 100.0).round(0)).zero?
              fraction = (index / (items_count / 100.0)).round(0)
              fraction = 100 if fraction > 100
              print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
            end
          else
            fraction = (((index * 1.0) / items_count) * 100.0).round(0)
            fraction = 100 if fraction > 100
            print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
          end
          index += 1

          logger.info("#{unoptimized} => #{optimized}") if optimized
        end
        puts "[#{'*' * 100}] 100% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"
        puts 'END'
        puts "--> OPTIMIZING time: #{((Time.zone.now - temp) / 60).to_i} min"
      end
    end
  end
end
