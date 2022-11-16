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

    def first_available_i18n_t(i18n_path, dynamic_part, i18n_options = {})
      I18n.exists?(i18n_path, **i18n_options) ? t(i18n_path, **i18n_options) : t(i18n_path.sub(".#{dynamic_part}.", '.').delete_prefix('.').delete_suffix('.'), **i18n_options)
    end

    def first_existing_partial(prefix)
      return "#{prefix}_#{action_name}" if lookup_context.exists?("#{prefix}_#{action_name}", lookup_context.prefixes, false)

      action_name
    end
  end
end
