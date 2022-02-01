# frozen_string_literal: true

module DataCycleCore
  module ArrayExtension
    def to_utf8
      collect do |v|
        if v.respond_to?(:to_utf8)
          v.to_utf8
        elsif v.is_a?(String) && v.respond_to?(:encoding)
          v.dup.encode('UTF-8', undef: :replace, invalid: :replace, replace: '')
        else
          v
        end
      end
    end

    def except(value)
      self - Array.wrap(value)
    end

    def deep_freeze
      each { |v| v.deep_freeze if v.respond_to?(:deep_freeze) }

      freeze
    end

    def dc_deep_dup
      dup.map { |v| v.respond_to?(:dc_deep_dup) ? v.dc_deep_dup : v }
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

Array.include DataCycleCore::ArrayExtension
