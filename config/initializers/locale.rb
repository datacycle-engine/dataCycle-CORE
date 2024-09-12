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

    module VersionDigest
      def reload!
        @version_digest = {}
        super
      end

      def version_digest(locale)
        locale = locale.to_sym
        return @version_digest[locale] if @version_digest&.key?(locale)

        @version_digest ||= {}
        @version_digest[locale] = Digest::MD5.hexdigest(translations(do_init: true)[locale].to_json)
      end
    end
  end
end

I18n.backend.class.send(:include, I18n::Backend::SpecificTranslation)
I18n.backend.class.send(:include, I18n::Backend::VersionDigest)
