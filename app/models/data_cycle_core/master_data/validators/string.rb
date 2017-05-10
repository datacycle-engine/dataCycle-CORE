module DataCycleCore
  module MasterData
    module Validators
      class String < BasicValidator

        @@string_keywords = ['minLength', 'maxLength', 'format', 'pattern']
        @@string_formats = ['date_time', 'date', 'uuid']


        def validate(data, template)
          if data.is_a?(::String)
            if template.has_key?("validations")
              template["validations"].keys.each do |key|
                if @@string_keywords.include?(key)
                  self.method(key).call(data, template["validations"][key])
                else
                  @error[:warning].push "#{key} is not a known keyword for a String. Found for #{data} in #{template}" unless key == "type"
                end
              end
            end
          else
            if data.blank?
              @error[:warning].push "No data given for #{template["label"]}."
            else
              @error[:error].push "#{template["label"]} is not a String, but #{data.class}."
            end
          end
          return @error
        end

      private
      # given string validations

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

        def pattern(data, expression)
          regex = /#{expression[1..expression.length-2]}/
          matched = data.match(regex)
          if matched.nil? || matched.offset(0) != [0,data.size]
            @error[:error].push "Expecting #{data} match format-string: #{expression}"
          end
        end

        def format(data, format_string)
          if @@string_formats.include?(format_string)
            self.method(format_string).call(data)
          else
            @error[:error].push "format-string #{format_string} given for #{data} unknown."
          end
        end

      # check string for given format

        def uuid(data)
          data.downcase!
          uuid = /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/
          check_uuid = data.length == 36 && !(data=~uuid).nil?
          unless check_uuid
            @error[:error].push "Expecting uuid for #{data}. format: 12345678-9abc-def0-1234-56789abcdef0"
          end
        end

        def date_time(data)
          begin
            data.to_datetime
          rescue
            @error[:error].push "Failed to convert #{data} to date_time format."
          end
        end

        def date(data)
          begin
            data.to_date
          rescue
            @error[:error].push "Failed to convert #{data} to date format."
          end
        end

      end
    end
  end
end
