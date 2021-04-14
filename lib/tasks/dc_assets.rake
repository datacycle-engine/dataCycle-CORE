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
    end
  end
end
