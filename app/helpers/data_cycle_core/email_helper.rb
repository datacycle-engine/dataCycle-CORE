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

    def first_available_i18n_t(i18n_path, dynamic_parts, **i18n_options)
      i18n_options[:scope] = i18n_options[:scope].then { |v| v.is_a?(::Array) ? v.map(&:to_s) : v.split('.') } if i18n_options.key?(:scope)

      Array.wrap(dynamic_parts).each do |dynamic_part|
        namespaced_path = i18n_path.to_s.split('.').map { |v| v == '?' ? dynamic_part : v }.compact_blank.join('.')

        if i18n_options.key?(:scope)
          namespaced_options = i18n_options.merge(scope: i18n_options[:scope].map { |v| v == '?' ? dynamic_part : v }.compact_blank.join('.'))
        else
          namespaced_options = i18n_options
        end

        return t(namespaced_path, **namespaced_options).html_safe if I18n.exists?(namespaced_path, **namespaced_options) # rubocop:disable Rails/OutputSafety
      end

      i18n_options[:scope] = i18n_options[:scope].except('?').compact_blank.join('.') if i18n_options.key?(:scope)
      clean_path = i18n_path.to_s.split('.').except('?').compact_blank.join('.')
      t(clean_path, **i18n_options).html_safe if I18n.exists?(clean_path, **i18n_options) # rubocop:disable Rails/OutputSafety
    end

    def first_existing_action_template(namespaces)
      Array.wrap(namespaces).each do |namespace|
        return "#{namespace}_#{action_name}" if lookup_context.exists?("#{namespace}_#{action_name}", lookup_context.prefixes, false)
      end

      action_name
    end

    def first_existing_layout(base, namespaces)
      Array.wrap(namespaces).each do |namespace|
        path = "#{namespace}_#{base}"
        path = "data_cycle_core/#{path}" unless path.starts_with?('data_cycle_core/')

        return path if lookup_context.exists?(path, ['layouts'], false, [], formats: [:html])
      end

      nil
    end

    def user_additional_tile_attribute_value(key, value, locale)
      return value unless value.acts_like?(:time) || key.end_with?('_at')
      return value if (v = value.try(:in_time_zone)).blank?

      l(v, locale: locale, format: :edit)
    end

    def layout_params(params, issuer = nil)
      params = params.with_indifferent_access
      viewer_layouts = []
      params[:template_namespaces] = []
      params[:template_namespaces].push(params[:mailer_layout]) if params[:mailer_layout].present?
      params[:template_namespaces].push(issuer) if issuer.present?
      viewer_layouts.push(params[:viewer_layout]) if params[:viewer_layout].present?
      viewer_layouts.push(issuer) if issuer.present?

      params.merge({
        'mailer_layout' => first_existing_layout('mailer', params[:template_namespaces]),
        'viewer_layout' => first_existing_layout('mailer', viewer_layouts)
      }).compact_blank
    end
  end
end
