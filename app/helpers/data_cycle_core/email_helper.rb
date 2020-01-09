# frozen_string_literal: true

module DataCycleCore
  module EmailHelper
    def email_image_tag(image, **options)
      logo_file_path = Rails.root.join('app', 'assets', 'images', "#{@locale || I18n.locale.to_s}_#{image}")
      logo_file_path = Rails.root.join('app', 'assets', 'images', image) unless File.exist?(logo_file_path)
      logo_file_path = DataCycleCore::Engine.root.join('app', 'assets', 'images', image) unless File.exist?(logo_file_path)
      attachments.inline[image] = File.read(logo_file_path)
      image_tag attachments[image].url, **options
    end
  end
end
