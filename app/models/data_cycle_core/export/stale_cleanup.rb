# frozen_string_literal: true

module DataCycleCore
  module Export
    # Sends the delete webhooks for the contents an earlier, wider export filter left behind at a
    # receiver: narrowing an endpoint takes a content out of it without ever telling the receiver.
    # Drives dc:sync:cleanup_exports. Every check stands between an operator and a mass delete, so
    # each one raises rather than skipping quietly.
    class StaleCleanup
      class Error < StandardError; end

      ACTION = 'update'

      attr_reader :external_system, :template_names, :execute

      # @param external_system [DataCycleCore::ExternalSystem] the receiver to clean up at
      # @param template_names [Array<String>, nil] restrict the cleanup to these templates
      # @param execute [Boolean] false only reports what would be deleted
      def initialize(external_system:, template_names: nil, execute: false)
        @external_system = external_system
        @template_names = Array.wrap(template_names)
        @execute = execute
      end

      # @yield [DataCycleCore::Thing] every stale content, before its delete is sent
      # @return [void]
      def call
        stale.find_each do |thing|
          yield thing if block_given?

          utility_object.process(thing) if execute
        end
      end

      # the exported contents no endpoint contains any more
      # @return [ActiveRecord::Relation]
      def stale
        return @stale if defined?(@stale)

        check!

        # each endpoint excluded by its own subquery: contained in none of them is what stale means,
        # and it keeps every id in the database rather than in a bind parameter per content
        @stale = endpoints.reduce(exported) { |query, endpoint| query.where.not(id: endpoint_things_all_locales(endpoint)) }
      end

      # everything this system holds, narrowed by +template_names+
      # @return [ActiveRecord::Relation]
      def exported
        return @exported if defined?(@exported)

        @exported = DataCycleCore::Thing.delivered_to(external_system)
        @exported = @exported.where(template_name: template_names) if template_names.present?

        @exported
      end

      private

      def check!
        raise Error, 'export_config missing!' if external_system.export_config.blank?
        raise Error, 'delete webhook missing!' if utility_object.webhook.nil?

        # this builds its own PushObject and so never passes the Webhook::Base allowlist checks;
        # without this a staging host would send its deletes to the production receiver
        raise Error, "#{external_system.name} is not enabled in WEBHOOKS!" if execute && Array.wrap(DataCycleCore.webhooks).exclude?(external_system.name)
        raise Error, "no endpoints configured for #{method_name}!" if endpoint_ids.blank?

        # an endpoint that does not resolve drops out of by_id_or_slug silently, and everything it
        # contains would be counted as no longer exported
        raise Error, "configured endpoints do not exist: #{missing_endpoint_ids.join(', ')}!" if missing_endpoint_ids.present?

        # an endpoint selecting nothing at all is a broken filter or an unbuilt cache, and the whole
        # export would read as stale. Deliberately not "contains none of the exported contents":
        # narrowing the run to a template that is entirely stale is what template_names is for.
        raise Error, "endpoints select no contents: #{empty_endpoints.map(&:name).join(', ')}!" if empty_endpoints.present?
      end

      def utility_object
        @utility_object ||= DataCycleCore::Export::PushObject.new(external_system:, action: :delete, filter_checked: true)
      end

      # the export filters are keyed by the strategy name, not by the action
      def method_name
        @method_name ||= external_system.export_filter_method_name(ACTION)
      end

      # the configured ids, not the resolved endpoints: what the guards below report on
      def endpoint_ids
        @endpoint_ids ||= DataCycleCore::Export::Generic::Filter.endpoint_ids_for(external_system, method_name)
      end

      # the resolution the export filter itself uses: a stale set computed against a different
      # endpoint set than the filter's is a delete for what the export still contains
      def endpoints
        @endpoints ||= Array.wrap(DataCycleCore::Export::Generic::Filter.endpoints_for(external_system, method_name))
      end

      def missing_endpoint_ids
        @missing_endpoint_ids ||= endpoint_ids.reject { |i| endpoints.any? { |e| i.in?([e.id, e.slug]) } }
      end

      def empty_endpoints
        @empty_endpoints ||= endpoints.reject { |endpoint| endpoint_things_all_locales(endpoint).exists? }
      end

      # Deliberately not DataCycleCore::Export::Generic::Filter.endpoint_things: things_nested drops
      # the locale the endpoint filters by, and a content still contained in any locale is at the
      # receiver for a reason. Reading the narrower set here would delete it.
      def endpoint_things_all_locales(endpoint)
        endpoint.things_nested.reorder(nil).select(:id)
      end
    end
  end
end
