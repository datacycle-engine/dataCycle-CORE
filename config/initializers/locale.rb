# frozen_string_literal: true

I18n.available_locales = [:de, :en]

module I18n
  module Backend
    module SpecificTranslation
      def lookup(locale, key, scope = [], options = {})
        if options[:specific].present?
          Array.wrap(options[:specific]).each do |specific|
            translation = super(locale, "#{key}.#{specific}", scope, options)
            return translation if translation.present?
          end
        end

        super(locale, key, scope, options)
      end
    end
  end
end

I18n.backend.class.send(:include, I18n::Backend::SpecificTranslation)
