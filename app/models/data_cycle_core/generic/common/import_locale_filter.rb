# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      # Language-neutral (untranslatable) properties are only imported from the primary locale
      # (I18n.default_locale). A secondary locale that does not carry them would otherwise reset
      # them to what its own pass happens to deliver - a classification the source only knows in
      # "de" gets deleted again by the "en" pass.
      module ImportLocaleFilter
        # Untranslatable data may only come from the primary locale, unless there is no primary
        # locale to take it from: brand new content, or content the source only delivers in a
        # secondary locale.
        #
        # A pending primary system change is the third exception: only the pass that detects it
        # carries the nil values #change_primary_system! merged in, and a later primary locale
        # pass no longer takes that branch - filtering them away would leak the old system's
        # values forever.
        def import_untranslatable?(content)
          return true if I18n.locale == I18n.default_locale || content.new_record?
          return true if content.external_source_id_changed?

          # not #translated_locales: that loads every translation row (with its content jsonb)
          # for every item of every secondary locale pass
          !content.translations.exists?(locale: I18n.default_locale)
        end

        # Drops every untranslatable property from +data+ in place, keeping the internal keys
        # the import still needs to identify the content.
        #
        # Embedded properties are exempt even when the relation itself is untranslatable
        # ('translated: true'): only the relation is shared across locales, the children carry
        # their own translations and get them from this very pass (see #set_embedded). Dropping
        # them would leave every embedded child untranslated in all but the primary locale.
        #
        # @param data [Hash] the data hash about to be passed to set_data_hash
        # @param content [DataCycleCore::Thing] the content being imported
        def keep_translatable_only!(data, content)
          data.slice!(
            *content.translatable_property_names,
            *content.untranslatable_embedded_property_names,
            # 'id' is already excepted from the data hash by #create_or_update_content
            *(DataCycleCore::Content::Content::IMPORTABLE_INTERNAL_PROPERTY_NAMES - ['id'])
          )
        end
      end
    end
  end
end
