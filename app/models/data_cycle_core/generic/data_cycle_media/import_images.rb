# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DataCycleMedia
      module ImportImages
        def self.import_data(utility_object:, options:)
          import_locale_images(utility_object: utility_object, options: options)
        end

        def self.import_locale_images(utility_object:, options:)
          test_dir = '/var/www/app/test/dummy/tmp/upload_test'
          Dir[File.join(File.expand_path(test_dir), '**', '*.{gif,jpg,jpeg,png,tif,tiff,GIF,JPG,JPEG,PNG,TIF,TIFF}')].each do |p|
            relative_path = p.gsub(File.expand_path(test_dir), '')

            title = Pathname(Pathname(relative_path).each_filename.to_a[-1]).sub_ext('').to_s
            file = File.open(p)

            ### process DataCycleImage
            image_file = DataCycleCore::Image.new(file: file)
            next unless image_file.save

            image_data = {
              headline: title,
              asset: image_file.id,
              external_key: relative_path
            }
            new_object = process_content(utility_object: utility_object, raw_data: image_data, options: options)
            next unless new_object
            # File.delete(p)
          end
        end

        def self.process_content(utility_object:, raw_data:, options:)

          config = options.dig(:import, :transformations, :image)
          type = config&.dig(:content_type)&.constantize || DataCycleCore::CreativeWork
          template = config&.dig(:template) || 'DataCycle - Bild'

          DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
            utility_object: utility_object,
            class_type: type,
            template: DataCycleCore::Generic::Common::ImportFunctions.load_template(type, template),
            data: DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
              config,
              raw_data
            ).with_indifferent_access
          )
        end
      end
    end
  end
end
