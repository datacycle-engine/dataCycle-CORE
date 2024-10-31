# frozen_string_literal: true

module DataCycleCore
  module HashExtension
    def to_utf8
      to_h do |k, v|
        if v.respond_to?(:to_utf8)
          [k, v.to_utf8]
        elsif v.is_a?(String) && v.respond_to?(:encoding)
          [k, v.dup.encode('UTF-8', undef: :replace, invalid: :replace, replace: '')]
        else
          [k, v]
        end
      end
    end

    def deep_reject(&)
      each_with_object({}) do |(k, v), memo|
        if v.is_a?(Hash)
          memo[k] = v.deep_reject(&)
        elsif v.is_a?(Array)
          memo[k] = v.map { |val|
            val.is_a?(Hash) ? val.deep_reject(&) : val
          }.reject { |val| yield(k, val) }
        else
          memo[k] = v
        end

        memo.delete(k) if yield(k, memo[k])
      end
    end

    def deep_reject!(&)
      each do |k, v|
        v.deep_reject!(&) if v.is_a?(Hash)

        if v.is_a?(Array)
          v.each { |val|
            val.deep_reject!(&) if val.is_a?(Hash)
          }.reject! { |val| yield(k, val) }
        end

        delete(k) if yield(k, v)
      end
    end

    def deep_compact
      deep_reject { |_, v| v.nil? }
    end

    def deep_compact!
      deep_reject! { |_, v| v.nil? }
    end

    def deep_compact_blank
      deep_reject { |_, v| v.blank? }
    end

    def deep_compact_blank!
      deep_reject! { |_, v| v.blank? }
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

    def dc_deep_transform_values(&)
      _dc_deep_transform_values_with_self(self, &)
    end

    def _dc_deep_transform_values_with_self(object, &)
      case object
      when Hash
        yield(object.transform_values { |value| _dc_deep_transform_values_with_self(value, &) })
      when Array
        yield(object.map { |e| _dc_deep_transform_values_with_self(e, &) })
      else
        yield(object)
      end
    end

    def dc_deep_set_value!(path, value)
      path = Array.wrap(path).dup
      key = path.shift
      next_type = path.first.is_a?(Integer) ? ::Array : ::Hash

      return if self[key].present? && !self[key].is_a?(next_type)

      if path.blank?
        self[key] = value
      else
        (self[key] ||= next_type.new).dc_deep_set_value!(path, value)
      end

      self
    end
  end
end

Hash.include DataCycleCore::HashExtension
