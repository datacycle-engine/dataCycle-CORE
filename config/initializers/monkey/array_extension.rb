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
      self - Array(value)
    end

    def deep_freeze
      each { |v| v.deep_freeze if v.respond_to?(:deep_freeze) }

      freeze
    end

    def dc_deep_dup
      dup.map { |v| v.respond_to?(:dc_deep_dup) ? v.dc_deep_dup : v }
    end
  end
end

Array.include DataCycleCore::ArrayExtension
