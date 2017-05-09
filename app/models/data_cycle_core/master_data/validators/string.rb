module MasterData
  module Validators
    class String < BasicValidator

      @@string_keywords = ['minLength', 'maxLength', 'format']
      @@String_formats = ['date_time']


      def validate(data, template)
        @error[:error].push "#{data} is not a String" unless data.is_a?(::String)
        if template.has_key?("validations")
          template["validations"].keys.each do |key|
            if @@string_keywords.include?(key)
              self.method(key).call(data, template["validations"][key])
            else
              @error[:warning].push "#{key} is not a known keyword for a String. Found for #{data} in #{template}" unless key == "type"
            end
          end
        end
        return @error
      end

      def minLength(data,value)
        if data.length < value.to_i
          @error[:error].push "#{data} length not long enough, should be #{value.to_i}, but is only #{data.length} long."
        end
      end

      def maxLength(data,value)
        if data.length > value.to_i
          @error[:error].push "String #{data} too long , should be #{value.to_i}, but is #{data.length} long."
        end
      end

      def date_time(data, template)
        puts "date_time"
      end

    end
  end
end
