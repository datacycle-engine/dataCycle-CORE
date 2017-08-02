module DataCycleCore
  module MasterData
    module Validators
      class Number < BasicValidator

        @@number_keywords =  ['min', 'max', 'format']
        @@number_formats = ['integer', 'float']


        def validate(data, template)
          if data.is_a?(Numeric)
            if template.has_key?("validations")
              template["validations"].keys.each do |key|
                if @@number_keywords.include?(key)
                  self.method(key).call(data, template["validations"][key])
                else
                  @error[:warning].push I18n.t :keyword, scope: [:validation, :warning], key: key, type: "Number" unless key == "type"
                end
              end
            end
          else
            if data.blank?
              @error[:warning].push I18n.t :no_data, scope: [:validation, :warning], data: template["label"]
            else
              @error[:error].push I18n.t :number, scope: [:validation, :errors], data: data, class: data.class, template: template['label']
            end
          end
          return @error
        end

      private

        #number validations
        def min(data, value)
          if data < value
            @error[:error].push I18n.t :min_number, scope: [:validation, :errors], data: data, value: value
          end
        end

        def max(data, value)
          if data > value
            @error[:error].push I18n.t :max_number, scope: [:validation, :errors], data: data, value: value
          end
        end

        def format(data, format_string)
          if @@number_formats.include?(format_string)
            self.method(format_string).call(data)
          else
            @error[:error].push I18n.t :format, scope: [:validation, :errors], data: data, format_string: format_string
          end
        end

        #check number for given format
        def integer(data)
          unless data.is_a?(Fixnum)
            @error[:error].push I18n.t :integer, scope: [:validation, :errors], data: data
          end
        end

        def float(data)
          unless data.to_f
            @error[:error].push I18n.t :float, scope: [:validation, :errors], data: data
          end
        end

      end
    end
  end
end
