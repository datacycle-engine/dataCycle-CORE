# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class BasicValidator
        attr_reader :error

        def initialize(data, template, template_key = '', strict = false, content = nil)
          @content = content
          @error = { error: {}, warning: {} }
          @template_key = template_key
          validate(data, template, strict)
        end

        def validate(data, template, strict = false)
        end

        def merge_errors(error_hash)
          @error.each_key do |key|
            @error[key].merge!(error_hash[key]) if error_hash.key?(key)
          end
        end

        def uuid?(data)
          data_clean = data.squish.downcase
          uuid = /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/
          check_uuid = data_clean.length == 36 && !(data_clean =~ uuid).nil?
          unless check_uuid
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.uuid',
              substitutions: {
                data:
              }
            }
          end

          check_uuid
        end

        private

        def validate_with_method(key, data, value)
          return unless self.class.private_method_defined?(key)

          m = method(key)
          return unless m.parameters.size == 2

          m.call(data, value)
        end

        def blank?(data)
          DataCycleCore::DataHashService.blank?(data)
        end

        def required(data, value)
          (@error[:error][@template_key] ||= []) << { path: 'validation.errors.required' } if value && blank?(data)
        end

        def soft_required(data, value)
          (@error[:warning][@template_key] ||= []) << { path: 'validation.warnings.required' } if value && blank?(data)
        end
      end
    end
  end
end
