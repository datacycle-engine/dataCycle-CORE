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
      each_with_object({}) do |(k, v), memo|
        if v.is_a?(Hash)
          memo[k] = v.deep_reject(&block)
        elsif v.is_a?(Array)
          memo[k] = v.map { |val|
            val.is_a?(Hash) ? val.deep_reject(&block) : val
          }.reject { |val| yield(k, val) }
        else
          memo[k] = v
        end

        memo.delete(k) if yield(k, memo[k])
      end
    end

    def deep_reject!(&block)
      each do |k, v|
        v.deep_reject!(&block) if v.is_a?(Hash)

        if v.is_a?(Array)
          v.each { |val|
            val.deep_reject!(&block) if val.is_a?(Hash)
          }.reject! { |val| yield(k, val) }
        end

        delete(k) if yield(k, v)
      end
    end

    def deep_freeze
      each_value do |v|
        v.deep_freeze if v.respond_to?(:deep_freeze)
      end

      freeze
    end

    def dc_deep_dup
      dup.each_with_object({}) do |(k, v), memo|
        memo[k] = v.respond_to?(:dc_deep_dup) ? v.dc_deep_dup : v
      end
    end

    # TODO: remove after rails 6 upgrade
    def deep_transform_values(&block)
      _deep_transform_values_in_object(self, &block)
    end

    # TODO: remove after rails 6 upgrade
    def _deep_transform_values_in_object(object, &block)
      case object
      when Hash
        object.transform_values { |value| _deep_transform_values_in_object(value, &block) }
      when Array
        object.map { |e| _deep_transform_values_in_object(e, &block) }
      else
        yield(object)
      end
    end
  end
end

Hash.include DataCycleCore::HashExtension
