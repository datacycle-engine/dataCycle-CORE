# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # Shorthand for I18n.t with the "mcp." namespace prefix shared by all tool and resource keys.
    module Translations
      # A tree name must not be split into an I18n path: tree names from import sources do contain
      # dots ("Feratel - Orte i. G."), and I18n splits the key at the separator -- via key.to_s.split,
      # so it does that even when the key is passed as a Symbol (which was meant as protection here
      # before, but is none: the lookup landed under mcp.concept_schemes."Feratel - Orte i" and
      # silently returned nil although the definition was in the locale file). Hence a separator
      # that cannot occur in a tree name.
      NAME_SEPARATOR = 1.chr

      module_function

      # Translates key under the "mcp." namespace; options are passed through to I18n.t.
      def t(key, **)
        I18n.t("mcp.#{key}", **)
      end

      # Definition of a classification tree from mcp.concept_schemes.<tree name>.description.
      # nil when the tree has no definition -- trees come mostly from import sources, so complete
      # coverage is neither enforceable nor sensible; the tools then omit the field rather than
      # shipping a placeholder.
      def concept_scheme_description(name, locale: I18n.locale)
        return if name.blank?

        I18n.t(:description, scope: [:mcp, :concept_schemes, name.to_s], locale:, separator: NAME_SEPARATOR, default: nil).presence
      end
    end
  end
end
