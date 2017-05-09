module DataCycleCore
  module MasterData
    module Validators
      class Number < BasicValidator

        @@number_keywords =  ['min', 'max', 'format']
        @@number_formats = ['integer', 'float']


        def validate(data, template)
          @error[:error].push "#{data} is not a Numeric" unless data.is_a?(Numeric)
          template.keys.each do |key|
            if @@number_keywords.include?(key)
              self.method(key).call(data, template[key])
            else
              @error[:warning].push "#{key} is not a known keyword for a Number. Found for #{data} in #{template}" unless key == "type"
            end
          end
          return @error
        end

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

      end
    end
  end
end
