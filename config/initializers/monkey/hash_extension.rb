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

    def deep_reject(&block)
      dup.deep_reject!(&block)
    end

    def deep_reject!(&block)
      each do |k, v|
        v.deep_reject!(&block) if v.is_a?(Hash)

        if v.is_a?(Array)
          v.each do |val|
            val.deep_reject!(&block) if val.is_a?(Hash)
          end
        end

        delete(k) if yield(k, v)
      end
    end
  end
end

Hash.include DataCycleCore::HashExtension
