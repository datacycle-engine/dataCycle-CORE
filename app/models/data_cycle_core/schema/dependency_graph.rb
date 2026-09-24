# frozen_string_literal: true

module DataCycleCore
  class Schema
    # Dependency data for the /schema "Abhängigkeiten" view (moved out of
    # SchemaController): the per-template connection rows for the detail table,
    # an aggregated template→template graph for the visual dependency overview
    # (nodes with outgoing edges, reverse "used by" edges and cycle detection)
    # and the four header stats. Consumes the same OpenAPI document / presenters
    # as the detail page (single source of truth).
    class DependencyGraph
      # Expected-type kinds that count as a "connection" (a property that points
      # at another type rather than holding a plain value): a routable template,
      # a shared object type (PostalAddress, QuantitativeValue, …) or a geo type.
      # Scalars (text/number/…) and classifications are not connections.
      CONNECTION_KINDS = [:reference, :shared, :geo].freeze

      # Plain-data snapshot with the reader API the views use, so a cache hit does
      # not have to rebuild the presenters (see .cached).
      Snapshot = Data.define(:rows, :stats, :edge_count, :graph) do
        # same name the live object exposes, so views do not care which one they got
        def to_graph
          graph
        end
      end

      # Building the rows means asking the OpenAPI document for every template's
      # presenter, which dominates the page (~0.4s on a mid-sized instance) and
      # produces the same result until a template changes. Cached against the
      # newest template timestamp, with a short TTL as a backstop for everything
      # the key cannot see.
      #
      # What the TTL buys is a deliberate trade: `thing_counts` flows into the rows,
      # so the content numbers on the page can lag by up to `expires_in`. They are
      # an overview figure, not a live count — but that is the reason the TTL is
      # minutes rather than hours.
      def self.cached(schema:, locale:, thing_counts:, overlay_names: [], expires_in: 10.minutes)
        key = [
          'data_cycle_core', 'schema', 'dependency_graph', locale,
          DataCycleCore::ThingTemplate.maximum(:updated_at), overlay_names.sort
        ]

        Snapshot.new(**Rails.cache.fetch(key, expires_in:) do
          graph = new(schema:, locale:, thing_counts:, overlay_names:)
          { rows: graph.rows, stats: graph.stats, edge_count: graph.edge_count, graph: graph.to_graph }
        end)
      end

      attr_reader :rows

      def initialize(schema:, locale:, thing_counts:, overlay_names: [])
        @thing_counts = thing_counts
        document = Schema::Document.new(locale:)
        content_types = DataCycleCore::ThingTemplate.all.to_h { |t| [t.template_name, t.schema['content_type']] }

        @presenters = schema.templates
          .reject { |t| overlay_names.include?(t.template_name) }
          .filter_map { |t| document.template(t.template_name) }

        @rows = @presenters.filter_map { |tp| dependency_row(tp, content_types) }
          .sort_by { |row| row[:template_name].to_s.downcase }

        @nodes = build_nodes
      end

      # Header stats for the dependency view, mirroring its four tiles: templates
      # with outgoing dependencies, connections, templates without outgoing
      # dependencies and templates that are part of a dependency cycle.
      #
      # `connections` deliberately counts property→target pairs, so the tile
      # matches the table right below it row for row. The graph draws the
      # aggregated template→target edges instead, which is a smaller number
      # whenever several properties of a template point at the same type — that
      # one is #edge_count and belongs next to the graph, not into this tile row.
      def stats
        {
          schemas: @rows.size,
          connections: connection_count,
          independent: @presenters.size - @rows.size,
          circular: circular_node_ids.size
        }
      end

      # One per property→target pair, i.e. exactly the rows the detail table
      # renders.
      def connection_count
        @connection_count ||= @rows.sum { |row| row[:connections].sum { |connection| connection[:targets].size } }
      end

      # One per source→target pair, i.e. the edges the graph draws. Several
      # properties pointing at the same type collapse into one edge here.
      def edge_count
        @edge_count ||= @nodes.values.sum { |node| node[:deps].size }
      end

      # Graph payload for the client-side dependency overview: every node
      # (source templates, their targets and non-routable shared/geo types) with
      # its aggregated outgoing edges (target + number of referencing
      # properties), the reverse "used by" edges and a cycle marker.
      def to_graph
        circular = circular_node_ids
        {
          nodes: @nodes.values.map { |node| node.merge(circular: circular.include?(node[:id])) },
          stats:,
          edges: edge_count
        }
      end

      private

      # One dependency row (a template + its connection properties), or nil when
      # the template has no connections.
      def dependency_row(template_presenter, content_types)
        connections = connection_properties(template_presenter, content_types)
        return nil if connections.empty?

        {
          template_name: template_presenter.template_name,
          content_type: template_presenter.content_type,
          group: Schema.node_group(template_presenter.content_type),
          content_count: @thing_counts.fetch(template_presenter.template_name, 0),
          connections:
        }
      end

      # A template's connection properties: [{ key:, label:, cardinality:, targets: [...] }].
      # Each target carries its display label, chip kind, routable template id (if any)
      # and "Verwendungen" (the target template's content count, nil for non-routable
      # shared/geo types).
      def connection_properties(template_presenter, content_types)
        template_presenter.properties.filter_map do |property|
          targets = property.expected_type.select { |descriptor| CONNECTION_KINDS.include?(descriptor[:kind]) }
          next if targets.empty?

          {
            key: property.api_name,
            label: property.label,
            cardinality: property.cardinality,
            targets: targets.map { |descriptor| connection_target(descriptor, content_types) }
          }
        end
      end

      # One target-type descriptor enriched with its content_type + usage count.
      def connection_target(descriptor, content_types)
        template_id = descriptor[:template]
        {
          label: descriptor[:label],
          kind: descriptor[:kind],
          template: template_id,
          content_type: template_id && content_types[template_id],
          group: Schema.node_group(template_id && content_types[template_id]),
          usage: template_id && @thing_counts.fetch(template_id, 0)
        }
      end

      # Aggregates the property-level rows into one node per type. A node id is
      # the template name (or the display label for non-routable shared/geo
      # types); edges are unique per source→target and carry the number of
      # referencing properties, mirrored onto the target as "used by".
      def build_nodes
        nodes = {}

        # every shown template is a node, including dependency-free ones
        @presenters.each do |tp|
          nodes[tp.template_name] = {
            id: tp.template_name,
            group: Schema.node_group(tp.content_type),
            content_count: @thing_counts.fetch(tp.template_name, 0),
            deps: {},
            used_by: {}
          }
        end

        @rows.each do |row|
          source = nodes[row[:template_name]]
          row[:connections].each do |connection|
            connection[:targets].each do |target|
              id = target[:template].presence || target[:label]
              nodes[id] ||= {
                id:,
                group: Schema.node_group(target[:content_type]),
                content_count: target[:usage],
                deps: {},
                used_by: {}
              }
              source[:deps][id] = source[:deps].fetch(id, 0) + 1
              nodes[id][:used_by][row[:template_name]] = nodes[id][:used_by].fetch(row[:template_name], 0) + 1
            end
          end
        end

        nodes
      end

      # Ids of all nodes that sit on at least one dependency cycle (including
      # self-references), via an iterative DFS over the aggregated edges.
      def circular_node_ids
        @circular_node_ids ||= Set.new.tap do |circular|
          explored = Set.new
          @nodes.each_key do |start|
            next if circular.include?(start) || explored.include?(start)

            detect_cycles_from(start, circular, explored)
          end
        end
      end

      # Marks every node on a cycle reachable from `start`: walks the aggregated
      # edges depth-first and, when the current path closes back on itself, flags
      # the path segment that forms the loop.
      #
      # `explored` spans all starts: a node whose subgraph has been walked to the
      # end cannot contribute a new cycle, so it is skipped on later starts. It is
      # only recorded on pop (subgraph finished) and never shortcuts a node that
      # sits on the current path — that node is the cycle we are about to find.
      def detect_cycles_from(start, circular, explored)
        stack = [[start, @nodes[start][:deps].keys.dup]]
        path = [start]

        until stack.empty?
          node, pending = stack.last
          child = pending.shift

          if child.nil?
            stack.pop
            path.pop
            explored << node
            next
          end

          if (index = path.index(child))
            circular.merge(path[index..])
          elsif explored.exclude?(child)
            stack << [child, @nodes[child][:deps].keys.dup]
            path << child
          end
        end

        circular
      end
    end
  end
end
