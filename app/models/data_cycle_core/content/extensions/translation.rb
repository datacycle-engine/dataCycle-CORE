# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Translation
        extend ActiveSupport::Concern

        def attribute_translatable?(attribute, definition = nil)
          return if attribute.blank?

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
          def human_property_name(attribute, options = {})
            @human_property_name ||= Hash.new do |h, k|
              h[k] = begin
                label = if k[0].present? && I18n.exists?("attribute_labels.#{k[3]}.#{k[2]&.template_name}.#{k[0]}", count: k[5], locale: k[4])
                          I18n.t("attribute_labels.#{k[3]}.#{k[2]&.template_name}.#{k[0]}", count: k[5], locale: k[4])
                        elsif k[0].present? && I18n.exists?("attribute_labels.#{k[2]&.template_name}.#{k[0]}", count: k[5], locale: k[4])
                          I18n.t("attribute_labels.#{k[2]&.template_name}.#{k[0]}", count: k[5], locale: k[4])
                        elsif k[0].present? && I18n.exists?("attribute_labels.#{k[3]}.#{k[0]}", count: k[5], locale: k[4])
                          I18n.t("attribute_labels.#{k[3]}.#{k[0]}", count: k[5], locale: k[4])
                        elsif k[0].present? && I18n.exists?("attribute_labels.#{k[0]}", count: k[5], locale: k[4])
                          I18n.t("attribute_labels.#{k[0]}", count: k[5], locale: k[4])
                        else
                          k.dig(1, 'ui', k[3], 'label').presence ||
                            k.dig(1, 'label').presence ||
                            k.dig(1, 'tree_label').presence ||
                            k[0].titleize
                        end

                label += " (#{I18n.locale})" if k[2].attribute_translatable?(k[0], k[1])

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
