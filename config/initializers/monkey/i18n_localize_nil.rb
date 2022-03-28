# frozen_string_literal: true

module I18n
  class << self
    alias original_localize localize

    def localize(object, **options)
      return if object.blank?

      original_localize(object, **options)
    end
  end
end
