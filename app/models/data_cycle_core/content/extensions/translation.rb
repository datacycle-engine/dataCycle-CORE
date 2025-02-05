# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Translation
        extend ActiveSupport::Concern

        def attribute_translatable?(attribute, definition = nil)
          return false if attribute.blank?

          definition ||= properties_for(attribute)

          I18n.available_locales.many? &&
            translatable? &&
            (
              (
                translatable_property?(attribute, definition) &&
                definition&.dig('type') != 'object'
              ) ||
              (
                definition&.dig('type') == 'embedded' &&
                !definition&.dig('translated')
              )
            )
        end

        def translated_template_name(locale)
          I18n.t("template_names.#{base_template_name}", default: base_template_name, locale:)
        end

        def translated_helper_text(key, locale)
          return unless I18n.exists?("helper_text.attributes.#{base_template_name}.#{key.attribute_name_from_key}.tooltip", locale:)

          I18n.t("helper_text.attributes.#{base_template_name}.#{key.attribute_name_from_key}.tooltip", locale:)
        end

        class_methods do
          def human_property_name(attribute, options = {})
            @human_property_name ||= Hash.new do |h, k|
              h[k] = begin
                label_finders = [
                  method(:translated_attribute_name),
                  method(:translated_attribute_label_hash),
                  method(:translated_attribute_fallback_name)
                ]
                if k.dig(:options, :definition, 'type') == 'classification' && k[:key] == 'universal_classifications'
                  label_finders.unshift(method(:translated_tree_label_name), method(:tree_label_name))
                elsif k.dig(:options, :definition, 'type') == 'classification'
                  label_finders.insert(2, method(:translated_tree_label_name))
                end

                label = label_finders.reduce(nil) { |acc, finder| acc || finder.call(**k).presence }

                add_translated_label_flag(label, **k)
              end
            end

            options = options&.symbolize_keys || {}
            options[:definition] ||= options[:base].properties_for(attribute)
            options[:ui_scope] = options[:ui_scope].to_s
            options[:locale] ||= I18n.locale
            options[:count] ||= 1
            options[:locale_string] = true if options[:locale_string].nil?

            @human_property_name[{ key: attribute.to_s, options:, display_locale: I18n.locale }]
          end

          def human_attribute_name(attribute, options = {})
            options = options.to_h if options.is_a?(ActionController::Parameters)

            return super unless options[:base]&.property_names&.include?(attribute.to_s) || options&.dig(:definition, 'label').present? || attribute.blank?

            human_property_name(attribute, options)
          end

          private

          def translated_attribute_label_hash(options:, **)
            return unless (label_hash = options.dig(:definition, 'label')).is_a?(::Hash)

            new_options = options.except(:definition)
            new_options[:count] = label_hash['count'] if label_hash['count'].present?

            label = []
            label << human_property_name(label_hash['key_prefix'], new_options) if label_hash['key_prefix'].present?
            label << human_property_name(label_hash['key'], new_options) if label_hash['key'].present?
            label << human_property_name(label_hash['key_suffix'], new_options) if label_hash['key_suffix'].present?
            label.compact_blank.join(' ')
          end

          def translated_attribute_name(key:, options:, **)
            return if key.blank?

            new_options = options.except(:base, :definition, :ui_scope, :locale_string).symbolize_keys
            ui_scope = options[:ui_scope].to_s
            template_name = options[:base]&.template_name

            if I18n.exists?("attribute_labels.#{ui_scope}.#{template_name}.#{key}", **new_options)
              I18n.t("attribute_labels.#{ui_scope}.#{template_name}.#{key}", **new_options)
            elsif I18n.exists?("attribute_labels.#{template_name}.#{key}", **new_options)
              I18n.t("attribute_labels.#{template_name}.#{key}", **new_options)
            elsif I18n.exists?("attribute_labels.#{ui_scope}.#{key}", **new_options)
              I18n.t("attribute_labels.#{ui_scope}.#{key}", **new_options)
            elsif I18n.exists?("attribute_labels.#{key}", **new_options)
              I18n.t("attribute_labels.#{key}", **new_options)
            end
          end

          def translated_tree_label_name(options:, **)
            definition = options[:definition]
            locale = options[:locale]

            return unless definition&.dig('tree_label').present? && I18n.exists?("filter.#{definition['tree_label'].underscore_blanks}", locale:)

            I18n.t("filter.#{definition['tree_label'].underscore_blanks}", locale:)
          end

          def tree_label_name(options:, **)
            options&.dig(:definition, 'tree_label').presence
          end

          def translated_attribute_fallback_name(key:, options:, **)
            definition = options[:definition]

            definition&.dig('ui', options[:ui_scope], 'label').presence ||
              definition&.dig('label').presence ||
              definition&.dig('tree_label').presence ||
              key&.titleize
          end

          def add_translated_label_flag(label, options:, key:, display_locale:, **)
            return label unless options[:locale_string] && options[:base]&.attribute_translatable?(key, options[:definition])
            return label if label.blank? || label.include?("(#{display_locale})")

            label + " (#{display_locale})"
          end
        end
      end
    end
  end
end
