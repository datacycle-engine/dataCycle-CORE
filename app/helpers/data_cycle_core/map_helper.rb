# frozen_string_literal: true

module DataCycleCore
  module MapHelper
    def additional_map_values(contents, paths)
      return if paths.blank? || contents.blank?

      contents = Array.wrap(contents)
      paths = Array.wrap(paths)

      while paths.present?
        attribute_name = paths.shift

        if attribute_name.is_a?(Array)
          contents.map! { |c| additional_map_values(c, attribute_name) }
        else
          contents.map! { |c| c.try(attribute_name) }.flatten!
          contents.compact!
        end
      end

      contents.flatten.compact
    end
  end
end
