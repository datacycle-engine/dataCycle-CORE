# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for Schema::DependencyGraph — the aggregated template graph behind the
  # /schema "Abhängigkeiten" view (rows for the detail table, to_graph for the
  # client-side SchemaDependencyGraph component, stats for the header tiles).
  #
  # Every expectation is either a structural invariant (holds for any schema) or
  # derived from the live schema/DB at runtime — nothing about the concrete
  # template set, edge counts or ids is hard-coded, so the suite tracks the live
  # config instead of drifting from it (mirrors SchemaControllerTest).
  class DependencyGraphTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @schema = DataCycleCore::Schema.load_schema_from_database
      @dependency = DataCycleCore::Schema::DependencyGraph.new(
        schema: @schema,
        locale: I18n.default_locale,
        thing_counts: DataCycleCore::Thing.group(:template_name).count,
        overlay_names: []
      )
      @graph = @dependency.to_graph
      @nodes = @graph[:nodes].index_by { |node| node[:id] }
    end

    # ---- rows -----------------------------------------------------------------

    test 'rows has at most one entry per template' do
      names = @dependency.rows.pluck(:template_name)

      assert_equal names.uniq.size, names.size
    end

    test 'every row target that is routable resolves to a node in the graph' do
      routable_targets = @dependency.rows.flat_map { |row| row[:connections] }
        .flat_map { |connection| connection[:targets] }
        .filter_map { |target| target[:template] }

      skip 'no routable connection targets in this instance' if routable_targets.empty?

      routable_targets.each do |template_name|
        assert @nodes.key?(template_name), "expected a graph node for target '#{template_name}'"
      end
    end

    # ---- to_graph: aggregation --------------------------------------------------

    test 'stats.schemas matches the number of rows' do
      assert_equal @dependency.rows.size, @graph[:stats][:schemas]
    end

    # The tile above the detail table has to be countable in that table, so it
    # counts property->target pairs (one per rendered row). The graph draws them
    # aggregated per type pair, which is the smaller number whenever two
    # properties of a template point at the same type.
    test 'stats.connections matches the property->target rows of the detail table' do
      expected = @dependency.rows.sum do |row|
        row[:connections].sum { |connection| connection[:targets].size }
      end

      assert_equal expected, @graph[:stats][:connections]
      assert_equal expected, @dependency.connection_count
    end

    test 'edge_count matches the distinct template->target pairs derived from rows' do
      expected_edges = @dependency.rows.sum do |row|
        row[:connections].flat_map { |connection| connection[:targets] }
          .map { |target| target[:template].presence || target[:label] }
          .uniq
          .size
      end

      assert_equal expected_edges, @dependency.edge_count
      assert_equal expected_edges, @graph[:edges]
    end

    # The two numbers only differ where a template reaches the same type over
    # several properties — without such a case the assertion above would pass on a
    # single implementation for both.
    test 'connection_count exceeds edge_count where a template reaches one type over several properties' do
      duplicated = @dependency.rows.find do |row|
        targets = row[:connections].flat_map { |connection| connection[:targets] }
          .map { |target| target[:template].presence || target[:label] }
        targets.size > targets.uniq.size
      end

      skip 'no template in this instance reaches one type over several properties' if duplicated.nil?

      assert_operator @dependency.connection_count, :>, @dependency.edge_count
    end

    test 'a node\'s outgoing edge count equals the number of distinct targets in its row' do
      @dependency.rows.each do |row|
        node = @nodes.fetch(row[:template_name])
        expected_targets = row[:connections].flat_map { |connection| connection[:targets] }
          .map { |target| target[:template].presence || target[:label] }
          .uniq

        assert_equal expected_targets.sort, node[:deps].keys.sort,
                     "deps of '#{row[:template_name]}' must match its row's distinct targets"
      end
    end

    # ---- to_graph: deps/used_by are mirrored exactly ---------------------------

    test 'every outgoing edge is mirrored by a matching used_by entry on the target' do
      @graph[:nodes].each do |node|
        node[:deps].each do |target_id, count|
          target = @nodes[target_id]

          assert target, "target '#{target_id}' referenced by '#{node[:id]}' must itself be a node"
          assert_equal count, target[:used_by][node[:id]],
                       "'#{target_id}'.used_by['#{node[:id]}'] must mirror '#{node[:id]}'.deps['#{target_id}']"
        end
      end
    end

    test 'used_by carries no entries without a matching forward edge' do
      @graph[:nodes].each do |node|
        node[:used_by].each_key do |source_id|
          source = @nodes[source_id]

          assert source, "used_by source '#{source_id}' on '#{node[:id]}' must itself be a node"
          assert source[:deps].key?(node[:id]), "'#{source_id}' must have a forward edge to '#{node[:id]}'"
        end
      end
    end

    # ---- to_graph: cycle detection ----------------------------------------------
    # Cross-checked against an independently implemented (BFS, not the production
    # iterative-DFS) reachable-from-self walk, so this doesn't just re-assert
    # whatever the production algorithm already computed.

    def reachable_from_self?(id)
      queue = @nodes[id][:deps].keys.dup
      visited = Set.new
      until queue.empty?
        current = queue.shift
        return true if current == id
        next if visited.include?(current) || !@nodes.key?(current)

        visited << current
        queue.concat(@nodes[current][:deps].keys)
      end
      false
    end

    test 'circular is true for exactly the nodes reachable from themselves' do
      expected_circular = @nodes.each_key.select { |id| reachable_from_self?(id) }.to_set
      actual_circular = @nodes.each_value.select { |node| node[:circular] }.to_set { |node| node[:id] }

      assert_equal expected_circular, actual_circular
    end

    test 'a self-referencing template is flagged as circular' do
      self_referencing = @nodes.each_value.find { |node| node[:deps].key?(node[:id]) }

      skip 'no self-referencing template configured in this instance' if self_referencing.nil?

      assert self_referencing[:circular], "'#{self_referencing[:id]}' depends on itself and must be flagged circular"
    end
    # ---- cycle detection: shapes the live schema may not contain --------------
    # The detection walks the aggregated edges and marks nodes that lie on a loop.
    # It skips subgraphs it has already finished, which must never swallow a cycle
    # that is only reachable through a second branch — hence the diamond below.

    def cycles_for(edges)
      graph = DataCycleCore::Schema::DependencyGraph.allocate
      graph.instance_variable_set(
        :@nodes,
        edges.to_h { |id, targets| [id, { id:, deps: targets.index_with(1) }] }
      )
      graph.send(:circular_node_ids)
    end

    test 'a diamond whose shared branch closes a loop flags exactly that loop' do
      # A -> B -> D, A -> C -> D, D -> B: the cycle is B -> D -> B, and D is reached
      # over two branches, so the second one must not hit an "already explored"
      # shortcut before the loop is found
      circular = cycles_for('A' => ['B', 'C'], 'B' => ['D'], 'C' => ['D'], 'D' => ['B'])

      assert_equal Set['B', 'D'], circular
    end

    test 'a node on no loop is never flagged, however many paths lead to it' do
      circular = cycles_for('A' => ['B', 'C'], 'B' => ['D'], 'C' => ['D'], 'D' => [])

      assert_empty circular
    end

    test 'a self-reference is a loop of one' do
      assert_equal Set['A'], cycles_for('A' => ['A'])
    end

    test 'two independent loops are both found' do
      circular = cycles_for(
        'A' => ['B'], 'B' => ['A'],
        'C' => ['D'], 'D' => ['C'],
        'E' => ['A', 'C']
      )

      assert_equal Set['A', 'B', 'C', 'D'], circular
    end

    test 'a longer loop flags every node on it' do
      circular = cycles_for('A' => ['B'], 'B' => ['C'], 'C' => ['D'], 'D' => ['B'])

      assert_equal Set['B', 'C', 'D'], circular
    end
  end
end
