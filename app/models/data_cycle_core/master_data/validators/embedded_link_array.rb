module DataCycleCore
  module MasterData
    module Validators
      class EmbeddedLinkArray < BasicValidator
        @@keywords = ['min', 'max']

        # only allow single uuid referencing to a given table
        def validate(data, template)
          if is_blank?(data)
            @error[:warning].push I18n.t :no_data, scope: [:validation, :warnings], data: template['label'], locale: DataCycleCore.ui_language
            # @error[:warning].push "No data given for #{template['label']}."
          elsif data.is_a?(::Array)
            check_reference_array(data, template)
          elsif data.is_a?(::String)
            check_reference_array([data], template)
          else
            @error[:error].push I18n.t :data_type, scope: [:validation, :errors], data: data, template: template['label'], locale: DataCycleCore.ui_language
            # @error[:error].push "Wrong data type given for #{template['label']} (#{data}). Expected an UUID or an array of UUID's."
          end
          @error
        end

        private

        def check_reference_array(data, template)
          # validate given validations
          if template.key?('validations')
            template['validations'].keys.each do |key|
              if @@keywords.include?(key)
                method(key).call(data, template['validations'][key])
              else
                @error[:warning].push I18n.t :keyword, scope: [:validation, :warnings], key: key, type: 'EmbeddedLinkArray', locale: DataCycleCore.ui_language
              end
            end
          end

          # validate references
          data.each do |key|
            if key.is_a?(::String)
              validate_link = EmbeddedLink.new(key, template)
              merge_errors(validate_link.error) unless validate_link.nil?
            elsif key.is_a?(::Hash) && key.key?('id')
              validate_link = EmbeddedLink.new(key['id'], template)
              merge_errors(validate_link.error) unless validate_link.nil?
            else
              @error[:error].push I18n.t :data_format, scope: [:validation, :errors], key: key, template: template['label'], locale: DataCycleCore.ui_language
            end
          end
        end

        # validate nil,"",[],[nil],[""] as blank.
        def is_blank?(data)
          return true if data.blank?
          if data.is_a?(::Array)
            return true if data.length == 1 && data[0].blank?
          end
          false
        end

        def min(data, value)
          @error[:error].push I18n.t :min_ref, scope: [:validation, :errors], data: data.size, value: value, locale: DataCycleCore.ui_language if data.size < value
        end

        def max(data, value)
          @error[:error].push I18n.t :max_ref, scope: [:validation, :errors], data: data.size, value: value, locale: DataCycleCore.ui_language if data.size > value
        end
      end
    end
  end
end
