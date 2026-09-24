# frozen_string_literal: true

require 'test_helper'
require 'yaml'

module DataCycleCore
  # The release switches of the MCP layer, read from the file the GEM ships and not from
  # DataCycleCore.features: test/dummy/config/configurations/features.yml switches the layer and
  # both mounts on, so the merged hash every other MCP test sees is the opposite of what an
  # installation gets on upgrade -- the state these assertions are about.
  class McpTest < DataCycleCore::TestCases::ActiveSupportTestCase
    SHIPPED = YAML.safe_load_file(
      DataCycleCore::Engine.root.join('config', 'configurations', 'features.yml'),
      permitted_classes: [Symbol]
    ).fetch(:mcp).freeze

    # Both mounts shipped enabled once, against an empty host list. The mounts come from MOUNTS so
    # a third one is covered without a change here (as McpTestHelper#with_write_enabled does).
    #
    # fetch and not dig throughout: a renamed block would make every dig nil, which reads as "ships
    # off" and would pass this test while no mount is configured at all.
    test 'the gem ships the layer and both mounts off, writing included' do
      assert_not SHIPPED.fetch(:enabled), 'the MCP layer ships enabled'

      DataCycleCore::Feature::Mcp::MOUNTS.each do |mount|
        shipped_mount = SHIPPED.fetch(:mounts).fetch(mount)

        assert_not shipped_mount.fetch(:enabled), "mount #{mount} ships enabled"
        assert_not shipped_mount.fetch(:write_enabled), "mount #{mount} ships write_enabled"
      end
    end

    # The one switch that ships ON. Asserted because two prose places state that it is
    # (Feature::Mcp.resolution_trees and docs/mcp/setup.md), and a flip back would leave both
    # standing -- which is how they drifted once already. An empty resolution_trees would make the
    # cascade inert again without touching the switch, so the tree belongs in the same assertion.
    test 'the gem ships the geo cascade on, naming the tree dataCycle computes itself' do
      assert SHIPPED.fetch(:geo).fetch(:enabled), 'the geo cascade ships disabled'
      assert_includes SHIPPED.fetch(:geo).fetch(:resolution_trees), 'Administrative Einheiten'
    end

    # Through write_enabled?, which reads the mount unconditionally -- mount_enabled? short-circuits
    # on the layer's own switch and never reaches the name on an installation with MCP off.
    test 'an unknown mount name raises instead of reading as a disabled mount' do
      assert_raises(ArgumentError) { DataCycleCore::Feature::Mcp.write_enabled?(:globl) }
    end
  end
end
