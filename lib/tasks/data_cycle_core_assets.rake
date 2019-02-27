# frozen_string_literal: true

namespace :dc do
  namespace :assets do
    namespace :images do
      desc 'Optimize all Images'
      task optimize: :environment do
        image_optim = ::ImageOptim.new(DataCycleCore.image_optimizer_config)
        base = Rails.public_path.join('uploads', 'data_cycle_core', 'image', 'file')

        images = Dir.glob("#{base}/**/*.*")

        image_optim.optimize_images!(images) do |unoptimized, optimized|
          puts "#{unoptimized} => #{optimized}" if optimized
        end
      end
    end
  end
end
