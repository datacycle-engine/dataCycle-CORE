# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Collection < BasicValidator
        KEYWORDS = ['soft_api'].freeze

        def validate(data, template, _strict = false)
          if blank?(data)
            true
          elsif data.is_a?(::Array) || data.is_a?(ActiveRecord::Relation) || data.is_a?(::String)
            check_reference_array(Array.wrap(data), template)
          else
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.data_type',
              substitutions: {
                data:,
                template: template['label']
              }
            }
          end

          @error
        end

        private

        def check_reference_array(data, template)
          converted_data = convert_data(data, template)
          # validate given validations
          if template.key?('validations')
            template['validations'].each_key do |key|
              method(key).call(converted_data, template['validations'][key]) if KEYWORDS.include?(key)
            end
          end

          # validate references
          return if blank?(converted_data)

          validate_references(data, converted_data.pluck(:id), template)
        end

        def convert_data(data, template)
          converted_data = data.deep_dup
          converted_data = converted_data.ids if data.first.is_a?(ActiveRecord::Base)

          unless converted_data.all? { |d| d.is_a?(::String) && d.uuid? }
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.data_format',
              substitutions: {
                key: converted_data.filter { |d| !d.is_a?(::String) || !d.uuid? }.join(', '),
                template: template['label']
              }
            }
            return false
          end

          DataCycleCore::WatchList.where(id: converted_data) + DataCycleCore::StoredFilter.where(id: converted_data)
        end

        def validate_references(data, collection_ids, template)
          return true if collection_ids.size == data.size && data.to_set == collection_ids.to_set

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.not_found',
            substitutions: {
              key: (data - collection_ids).join(', '),
              template: template['label'],
              table: 'things'
            }
          }
        end

        def soft_api(data, _value)
          data.each do |collection|
            next if collection.try(:api)

            (@error[:warning][@template_key] ||= []) << {
              path: 'validation.warnings.collection.no_api',
              substitutions: {
                data: collection.name
              }
            }
          end
        end
      end
    end
  end
end
