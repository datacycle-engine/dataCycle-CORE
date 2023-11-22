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
          def translated_attribute_name(key, _definition, content, ui_scope, locale, _display_locale, count)
            return if key.blank?

            if I18n.exists?("attribute_labels.#{ui_scope}.#{content&.template_name}.#{key}", count:, locale:)
              I18n.t("attribute_labels.#{ui_scope}.#{content&.template_name}.#{key}", count:, locale:)
            elsif I18n.exists?("attribute_labels.#{content&.template_name}.#{key}", count:, locale:)
              I18n.t("attribute_labels.#{content&.template_name}.#{key}", count:, locale:)
            elsif I18n.exists?("attribute_labels.#{ui_scope}.#{key}", count:, locale:)
              I18n.t("attribute_labels.#{ui_scope}.#{key}", count:, locale:)
            elsif I18n.exists?("attribute_labels.#{key}", count:, locale:)
              I18n.t("attribute_labels.#{key}", count:, locale:)
            end
          end

          def translated_tree_label_name(_key, definition, _content, _ui_scope, locale, _display_locale, _count)
            return unless definition&.dig('tree_label').present? && I18n.exists?("filter.#{definition.dig('tree_label').underscore_blanks}", locale:)

            I18n.t("filter.#{definition.dig('tree_label').underscore_blanks}", locale:)
          end

          def translated_attribute_fallback_name(key, definition, _content, ui_scope, _locale, _display_locale, _count)
            definition&.dig('ui', ui_scope, 'label').presence ||
              definition&.dig('label').presence ||
              definition&.dig('tree_label').presence ||
              key&.titleize
          end

          def human_property_name(attribute, options = {})
            @human_property_name ||= Hash.new do |h, k|
              h[k] = begin
                label = if k[0] == 'universal_classifications' && k.dig(1, 'type') == 'classification'
                          translated_tree_label_name(*k).presence ||
                            k.dig(1, 'tree_label').presence ||
                            translated_attribute_name(*k).presence ||
                            translated_attribute_fallback_name(*k)
                        elsif k.dig(1, 'type') == 'classification'
                          translated_attribute_name(*k).presence ||
                            translated_tree_label_name(*k).presence ||
                            translated_attribute_fallback_name(*k)
                        else
                          translated_attribute_name(*k).presence ||
                            translated_attribute_fallback_name(*k)
                        end

                label += " (#{k[5]})" if k[2].attribute_translatable?(k[0], k[1])

                label
              end
            end

            @human_property_name[
              [
                attribute.to_s,
                options[:definition] || options[:base].properties_for(attribute),
                options[:base],
                options[:ui_scope].to_s,
                options[:locale] || I18n.locale,
                I18n.locale,
                options[:count] || 1
              ]
            ]
          end

          def human_attribute_name(attribute, options = {})
            return super unless options[:base]&.property_names&.include?(attribute.to_s)

            human_property_name(attribute, options)
          end
        end
      end
    end
  end
end
