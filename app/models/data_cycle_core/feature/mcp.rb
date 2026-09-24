# frozen_string_literal: true

module DataCycleCore
  module Feature
    # Configuration of the whole MCP layer: both mounts, their release, and the geo cascade the MCP
    # tools resolve place names with.
    #
    # ONE feature, where this used to be a main_config block per mount plus a separate
    # mcp_geo_scope feature. The mounts and the cascade are one subsystem released together, and
    # "what does an instance need for MCP" could not be answered from a single file before -- while
    # the routes beside the MCP ones (translate) already asked a Feature.
    #
    # The mount switches are read while the ROUTES ARE DRAWN (config/routes.rb), so they take
    # effect on restart rather than on the next request -- and a disabled mount has no route at all,
    # which is what lets a client see an honest 404 instead of a server that answers and then cannot
    # work.
    class Mcp < Base
      # The mounts, keyed under :mounts. Servers::GlobalServer and Servers::SingleEndpointServer
      # each name one of these as their MOUNT.
      MOUNTS = [:global, :endpoint].freeze

      class << self
        # @param mount [Symbol] :global or :endpoint
        # @return [Boolean] whether that mount is served -- the layer's switch AND the mount's own.
        def mount_enabled?(mount)
          enabled? && mount_configuration(mount)[:enabled].present?
        end

        # Whether create_content/update_content ship on that mount. A second switch on purpose, so
        # an upgrade cannot slip write tools into an installation that only reads.
        def write_enabled?(mount)
          mount_configuration(mount)[:write_enabled].present?
        end

        # Browser origins allowed to call the mount. Empty means same-origin; a client that sends no
        # Origin header (every non-browser client) is unaffected. The allowed HOSTS are deliberately
        # not here -- the transport is handed Rails.application.config.hosts, the list
        # ActionDispatch::HostAuthorization checks anyway (see McpTransportConcern).
        def allowed_origins(mount)
          Array.wrap(mount_configuration(mount)[:allowed_origins])
        end

        # Instance-specific notes both mounts append to their server instructions
        # (Mcp::ServerInstructions): a language-keyed hash, or a single string for every language.
        def instance_notes
          configuration[:instance_notes]
        end

        # Whether Mcp::GeoScope resolves at all. Without it -- or without a resolution tree -- the
        # place filter stays ineffective and resolve_place says so, rather than silently counting
        # over the whole set.
        def geo_enabled?
          enabled? && geo_configuration[:enabled].present?
        end

        # Trees in which a place name is resolved to a concept. Order = priority for ambiguous
        # place names: in vcloud-dev "Vorarlberg" exists as a concept in four trees (Administrative
        # Einheiten, Feratel - Orte, Feratel - Marketinggruppen, Eyebase - Tags); without a fixed
        # order the result would hang on whichever tree is found first.
        #
        # The default names the one tree dataCycle computes itself: data_cycle_basic's
        # administrative_unit_classifications derives "Administrative Einheiten" from the content's
        # geometry. Every further tree is instance-specific and is added by the project. The default
        # ships active (:geo: :enabled: is true): an instance that does not seed that tree finds no
        # ConceptScheme, so Mcp::GeoScope.resolve returns nil for every place name.
        def resolution_trees
          Array.wrap(geo_configuration[:resolution_trees])
        end

        # Trees whose concepts carry polygons and are matched by CONTAINMENT rather than by name --
        # stage 2, for the region names that do not exist in the resolution trees at all. Empty in
        # the gem: a resolution tree named here again would only repeat stage 1.
        def geo_region_trees
          Array.wrap(geo_configuration[:geo_region_trees])
        end

        # { "<concept name>" => "<POSIX regex against address.postal_code>" }
        def postal_code_patterns
          (geo_configuration[:postal_code_patterns] || {}).transform_keys(&:to_s)
        end

        # Prefixes stripped from the concept name before it is compared with address_locality
        # ("Gemeinde Egg" -> "Egg"). nil when the list is empty: the shipped prefixes are the German
        # ones of "Administrative Einheiten", which an instance with differently named concepts
        # replaces.
        def locality_prefix_pattern
          prefixes = Array.wrap(geo_configuration[:locality_prefixes]).compact_blank
          return if prefixes.blank?

          /\A(?:#{prefixes.map { |prefix| Regexp.escape(prefix) }.join('|')}) /
        end

        private

        # Raises rather than treating an unknown mount as an unconfigured one: read as {} it would
        # report the mount as disabled, the route would be missing, and nothing would name the typo.
        def mount_configuration(mount)
          raise ArgumentError, "unknown MCP mount #{mount.inspect}, expected one of #{MOUNTS.inspect}" unless mount.to_sym.in?(MOUNTS)

          configuration.dig(:mounts, mount.to_sym) || {}
        end

        def geo_configuration
          configuration[:geo] || {}
        end
      end
    end
  end
end
