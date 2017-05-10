module DataCycleCore
  module MasterData
    module Validators
      class Pattern < BasicValidator

        @@pattern_keywords = ['format']

        def validate(data, template)
          @error[:error].push "#{data} is not a RegEx" unless data.is_a?(::String)
          if template.has_key?("validations")
            template["validations"].keys.each do |key|
              if @@pattern_keywords.include?(key)
                self.method(key).call(data, template["validations"][key])
              else
                @error[:warning].push "#{key} is not a known keyword for a pattern. Found for #{data} in #{template}" unless key == "type"
              end
            end
          else
            @error[:error].push "No format-string with an regular expression given."
          end
          return @error
        end

        def format(data, expression)
          regex = /#{expression[1..expression.length-2]}/
          matched = data.match(regex)
          unless matched.offset(0) == [0,data.size]
            @error[:error].push "Expecting #{data} match format-string: #{expression}"
          end
        end

      end
    end
  end
end
