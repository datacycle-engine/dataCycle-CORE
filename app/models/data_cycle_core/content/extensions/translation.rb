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

        class_methods do
          def translated_attribute_name(key:, options: {}, **)
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

            return unless definition&.dig('tree_label').present? && I18n.exists?("filter.#{definition.dig('tree_label').underscore_blanks}", locale:)

            I18n.t("filter.#{definition.dig('tree_label').underscore_blanks}", locale:)
          end

          def translated_attribute_fallback_name(key:, options: {}, **)
            definition = options[:definition]

            definition&.dig('ui', options[:ui_scope], 'label').presence ||
              definition&.dig('label').presence ||
              definition&.dig('tree_label').presence ||
              key&.titleize
          end

          def overlay_propery_name(key:, options: {}, **)
            overlay_type = MasterData::Templates::Extensions::Overlay.overlay_attribute_type(key&.attribute_name_from_key)

            [
              human_property_name(options&.dig(:definition, 'features', 'overlay', 'overlay_for'), options.except(:definition)),
              I18n.t("feature.overlay.label_postfix.#{overlay_type}", locale: options[:locale])
            ].join(' ')
          end

          def human_property_name(attribute, options = {})
            @human_property_name ||= Hash.new do |h, k|
              h[k] = begin
                label = if k.dig(:options, :definition, 'features', 'overlay', 'overlay_for').present?
                          next overlay_propery_name(**k)
                        elsif k[:key] == 'universal_classifications' && k.dig(:options, :definition, 'type') == 'classification'
                          translated_tree_label_name(**k).presence ||
                            k.dig(:options, :definition, 'tree_label').presence ||
                            translated_attribute_name(**k).presence ||
                            translated_attribute_fallback_name(**k)
                        elsif k.dig(:options, :definition, 'type') == 'classification'
                          translated_attribute_name(**k).presence ||
                            translated_tree_label_name(**k).presence ||
                            translated_attribute_fallback_name(**k)
                        else
                          translated_attribute_name(**k).presence ||
                            translated_attribute_fallback_name(**k)
                        end

                label += " (#{k[:display_locale]})" if k.dig(:options, :base)&.attribute_translatable?(k[:key], k.dig(:options, :definition)) && k.dig(:options, :locale_string)

                label
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
        end
      end
    end
  end
end
