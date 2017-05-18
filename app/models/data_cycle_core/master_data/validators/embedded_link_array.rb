module DataCycleCore
  module MasterData
    module Validators
      class EmbeddedLinkArray < BasicValidator

        # only allow single uuid referencing to a given table
        def validate(data, template)
          if data.blank?
            @error[:warning].push "No data given for #{template['label']}."
          elsif data.is_a?(::Array)
            data.each do |key|
              if key.is_a?(::String)
                validate_link = EmbeddedLink.new(key,template)
                merge_errors(validate_link.error) unless validate_link.nil?
              else
                @error[:error].push "Elements of the link-array given for #{template['label']} have the wrong format (#{key})."
              end
            end
          elsif data.is_a?(::String)
            validate_link = EmbeddedLink.new(data,template)
            merge_errors(validate_link.error) unless validate_link.nil?
          else
            @error[:error].push "Wrong data type given for #{template['label']} (#{data}). Expected an UUID or an array of UUID's."
          end
          return @error
        end

      end
    end
  end
end
