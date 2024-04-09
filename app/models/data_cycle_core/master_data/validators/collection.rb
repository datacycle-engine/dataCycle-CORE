# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Collection < BasicValidator
        KEYWORDS = [].freeze

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
          converted_data = data.deep_dup
          converted_data = converted_data.ids if data.first.is_a?(ActiveRecord::Base)
          # validate given validations
          if template.key?('validations')
            template['validations'].each_key do |key|
              method(key).call(converted_data, template['validations'][key]) if KEYWORDS.include?(key)
            end
          end

          # validate references
          return if blank?(converted_data)

          validate_references(converted_data, template)
        end

        def validate_references(data, template)
          unless data.all? { |d| d.is_a?(::String) && d.uuid? }
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.data_format',
              substitutions: {
                key: data.filter { |d| !d.is_a?(::String) || !d.uuid? }.join(', '),
                template: template['label']
              }
            }
            return false
          end

          collections = DataCycleCore::WatchList.where(id: data).ids + DataCycleCore::StoredFilter.where(id: data).ids

          return true if collections.size == data.size && data.to_set == collections.to_set

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.not_found',
            substitutions: {
              key: (data.to_set - collections.to_set).join(', '),
              template: template['label'],
              table: 'things'
            }
          }
        end
      end
    end
  end
end
