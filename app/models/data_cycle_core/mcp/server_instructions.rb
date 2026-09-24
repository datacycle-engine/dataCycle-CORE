# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # The server instructions of a mount: the only text a client sees BEFORE its first tool call
    # (initialize or server/discover, see MCP::Server#init). Until now that field was empty and
    # everything mount-wide sat spread across the individual tool descriptions -- a client that
    # reads only the tool list to decide WHICH tool to take had not yet seen the result space or the
    # order of work.
    #
    # Assembled from localized building blocks (mcp.instructions.*) rather than one text per mount:
    # result space and write permission differ per mount and configuration, while the procedure and
    # the reporting duty are identical for both. Maintained as two full texts, the shared parts
    # would drift apart and the instance with write_enabled would silently get the read-only
    # version.
    #
    # DELIBERATELY WITHOUT MEASURED VALUES, tempting as the field is for them: instructions is
    # collected in the MCP::Server constructor, and that runs on EVERY request (both controllers
    # rebuild the server per request) -- yet the field is read only by initialize/discover. A COUNT
    # over the endpoint's result space would therefore hang off every tools/call, for a value that
    # call never delivers. search_contents without a filter answers the size of the result space on
    # demand; Mcp::ConceptSchemeMetrics supplies the tree metrics where they are needed. Only
    # already-available facts belong here: mount, endpoint name, write permission (configuration)
    # and language.
    class ServerInstructions
      # Order of the building blocks: first WHERE you are (result space), then in which language,
      # then HOW to work, then how to report a number, and last the write permission. A client that
      # truncates the text therefore loses the optional part first and not the result space.
      SHARED_KEYS = ['language', 'workflow', 'reporting'].freeze

      # @param locale [Symbol] language of the text (the same one as for tool/resource descriptions)
      # @param write_enabled [Boolean] whether the mount ships the writing tools
      # @param endpoint_name [String, nil] name of the endpoint; nil = global mount. The choice of
      #   the result-space block hangs off this (and not off a switch of its own) -- the same
      #   distinction Servers::Base#tool_description_options already makes for the tool descriptions.
      def initialize(locale:, write_enabled:, endpoint_name: nil)
        @locale = locale
        @write_enabled = write_enabled
        @endpoint_name = endpoint_name
      end

      # @return [String] the assembled instructions text.
      def call
        [*keys.map { |key| DataCycleCore::Mcp::Translations.t("instructions.#{key}", locale: @locale, **interpolations) }, instance_notes].compact.join("\n\n")
      end

      private

      # Instance-specific notes from the configuration (api.mcp.instance_notes), appended last.
      #
      # The channel exists so that statements ABOUT ONE instance need not sit in the gem:
      # "gastronomy is modelled here as TouristAttraction plus category, not as FoodEstablishment"
      # is right for this installation and a silent false assumption for every other -- yet it was
      # shipped to all of them. Sentences like that belong here (or, for a single endpoint, in its
      # description, which list_endpoints delivers).
      #
      # A language-keyed hash ({de: "...", en: "..."}) or a single string; without an entry for the
      # requested language it falls back to I18n.default_locale, so a note maintained only in German
      # is not lost on an English client.
      def instance_notes
        configured = DataCycleCore::Feature::Mcp.instance_notes
        return configured.presence if configured.is_a?(String)
        return if configured.blank?

        notes = configured.symbolize_keys
        (notes[@locale.to_sym] || notes[I18n.default_locale.to_sym]).presence
      end

      def keys
        [scope_key, *SHARED_KEYS, write_key]
      end

      def scope_key
        @endpoint_name.present? ? 'endpoint' : 'global'
      end

      def write_key
        @write_enabled ? 'write_enabled' : 'read_only'
      end

      # The same interpolations for every block: I18n ignores the ones a text does not need, and a
      # new block can use any of them without anything having to be added here.
      #
      # session_locale and not locale: with I18n.t, `locale` is a reserved options keyword (the
      # target language) and is therefore NOT available as an interpolation value -- a %{locale} in
      # the text would have raised a MissingInterpolationArgument, and in every initialize of this
      # mount at that.
      def interpolations
        {
          endpoint_name: @endpoint_name,
          session_locale: @locale,
          available_locales: I18n.available_locales.join(', ')
        }
      end
    end
  end
end
