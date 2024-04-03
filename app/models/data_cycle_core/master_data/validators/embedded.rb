# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Embedded < BasicValidator
        def keywords
          ['min', 'max', 'classifications']
        end

        def validate(data, template, _strict = false)
          if blank?(data) || data.is_a?(::Array) || data.is_a?(::Hash)
            check_data_array(Array.wrap(data), template)
          else
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.data_format_embedded',
              substitutions: {
                data:,
                template: template['label']
              }
            }
          end

          @error
        end

        private

        def check_data_array(data, template)
          # validate given validations
          if template.key?('validations')
            template['validations'].each_key do |key|
              method(key).call(data, template['validations'][key]) if keywords.include?(key)
            end
          end

          # validate references
          embedded_templates = Array.wrap(template['template_name']).index_with { |t| DataCycleCore::DataHashService.get_internal_template(t) }

          if template.blank? || embedded_templates.blank?
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.no_template',
              substitutions: {
                name: 'things'
              }
            }

            return
          end

          data.each do |item|
            next if item.blank?

            if item.is_a?(::Hash)
              template_name = template['template_name']
              if template_name.is_a?(Array)
                specific_template_name = item.dig(:datahash, :template_name).presence || item[:template_name].presence
                raise DataCycleCore::Error::TemplateNotAllowedError.new(specific_template_name, template_name) unless template_name.include?(specific_template_name)

                template_name = specific_template_name
              end

              validate_item(item, embedded_templates[template_name])
            else
              (@error[:error][@template_key] ||= []) << {
                path: 'validation.errors.data_format_embedded',
                substitutions: {
                  data:,
                  template: template['label']
                }
              }
            end
          end
        rescue ActiveModel::MissingAttributeError
          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.no_template',
            substitutions: {
              name: 'things'
            }
          }
        end

        def validate_item(item, template)
          if item[:translations].present?
            item[:translations].each do |locale, data|
              next unless data.is_a?(::Hash) && data.present?

              I18n.with_locale(locale) do
                validator_object = DataCycleCore::MasterData::ValidateData.new

                merge_errors(validator_object.validate(data.merge(item[:datahash] || {}), template.schema))
              end
            end
          else
            validator_object = DataCycleCore::MasterData::ValidateData.new
            merge_errors(validator_object.validate(item.key?(:datahash) ? item[:datahash] : item, template.schema))
          end
        end

        def classifications(values, _template_hash)
          classification_keys = DataCycleCore.features.dig(:publication_schedule, :classification_keys)

          return if values.blank? || classification_keys.blank?

          parsed_values = values.dc_deep_dup.each { |item|
            next unless item.is_a?(::Hash) && item.present?

            item = item['datahash'] if item.key?('datahash')
            item['id'] = SecureRandom.uuid if item['id'].blank?
          }.compact

          (@error[:error][@template_key] ||= []) << { path: 'validation.errors.classification_conflict' } if parsed_values.any? do |item|
            parsed_values.any? do |other_item|
              item != other_item && classification_keys.all? { |key| (Array.wrap(item[key]) & Array.wrap(other_item[key])).any? }
            end
          end
        end

        def min(data, value)
          return unless data.size < value

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.min_ref',
            substitutions: {
              data: data.size,
              value:
            }
          }
        end

        def max(data, value)
          return unless data.size > value

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.max_ref',
            substitutions: {
              data: data.size,
              value:
            }
          }
        end
      end
    end
  end
end
