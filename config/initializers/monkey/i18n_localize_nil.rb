# frozen_string_literal: true

module I18n
  class << self
    alias original_localize localize

    def localize(object, **)
      return if object.blank?

      original_localize(object, **)
    end
  end
end
