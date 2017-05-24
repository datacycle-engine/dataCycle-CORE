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
                  @error[:warning].push "#{key} is not a known keyword for a Number. Found for #{data} in #{template}" unless key == "type"
                end
              end
            end
          else
            if data.blank?
              @error[:warning].push "No data given for attribute #{template["label"]}."
            else
              @error[:error].push "#{template["label"]} is not a Numeric, but #{data.class} (value: #{data})."
            end
          end
          return @error
        end

      private

        #number validations
        def min(data, value)
          if data < value
            @error[:error].push "Number #{data} too small. Should be #{value}, but is only #{data}."
          end
        end

        def max(data, value)
          if data > value
            @error[:error].push "Number #{data} too big. Should be #{value}, but is #{data}."
          end
        end

        def format(data, format_string)
          if @@number_formats.include?(format_string)
            self.method(format_string).call(data)
          else
            @error[:error].push "format-string #{format_string} given for #{data} unknown."
          end
        end

        #check number for given format
        def integer(data)
          unless data.is_a?(Fixnum)
            @error[:error].push "Data: #{data} is not an Integer."
          end
        end

        def float(data)
          unless data.to_f
            @error[:error].push "Data: #{data} is not an Float."
          end
        end

      end
    end
  end
end
