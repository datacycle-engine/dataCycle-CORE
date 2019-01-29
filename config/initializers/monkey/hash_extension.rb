# frozen_string_literal: true

module DataCycleCore
  module HashExtension
    def to_utf8
      Hash[
        collect do |k, v|
          if v.respond_to?(:to_utf8)
            [k, v.to_utf8]
          elsif v.is_a?(String) && v.respond_to?(:encoding)
            [k, v.dup.encode('UTF-8', undef: :replace, invalid: :replace, replace: '')]
          else
            [k, v]
          end
        end
      ]
    end
  end
end

Hash.include DataCycleCore::HashExtension
