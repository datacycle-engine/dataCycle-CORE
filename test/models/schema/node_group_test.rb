# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Schema.node_group is THE definition of the three groups every /schema surface
  # colours by (cards, dependency table, graph nodes, legend, sidebar). It used to
  # be restated per surface, and the copies drifted apart in the one way that is
  # invisible in a review: they agreed on the behaviour and disagreed on the NAME
  # of the third group ('external' vs. 'shared').
  #
  # That name is not decoration -- the return value is interpolated straight into
  # a CSS modifier (`schema-rel__dot--<group>`). A group whose class the stylesheet
  # does not define renders a dot in the neutral fallback colour, next to a legend
  # that shows the intended one. Nothing raises, nothing logs; the two surfaces
  # simply disagree.
  #
  # So this suite pins both halves of the contract: what node_group answers, and
  # that every answer has a rule in the stylesheet.
  class SchemaNodeGroupTest < ActiveSupport::TestCase
    SCSS_PATH = DataCycleCore::Engine.root.join('app/assets/stylesheets/modules/schema/_index.scss')

    test 'content types with an own template are grouped by whether they are embedded' do
      assert_equal 'main', DataCycleCore::Schema.node_group('entity')
      assert_equal 'main', DataCycleCore::Schema.node_group('container')
      assert_equal 'embedded', DataCycleCore::Schema.node_group('embedded')
    end

    # A shared schema.org / geo type has no own template, so no content_type -- the
    # dependency graph reaches those only as edge targets.
    test 'a missing content type is the external group' do
      assert_equal 'external', DataCycleCore::Schema.node_group(nil)
      assert_equal 'external', DataCycleCore::Schema.node_group('')
      assert_equal 'external', DataCycleCore::Schema.node_group('   ')
    end

    test 'node_group only ever answers one of the declared groups' do
      answers = ['entity', 'container', 'embedded', nil, '', 'something_new']
        .map { |content_type| DataCycleCore::Schema.node_group(content_type) }

      assert_empty answers.uniq - DataCycleCore::Schema::GROUPS
    end

    # The regression: `--shared` was renamed to `--external` in the stylesheet while
    # a JS copy of the mapping kept answering 'shared'. Reading the stylesheet here
    # is deliberate -- it is the only place the two vocabularies actually meet, and
    # a rename on either side has to fail loudly instead of quietly greying a dot.
    test 'every group has a dot modifier in the schema stylesheet' do
      scss = SCSS_PATH.read

      DataCycleCore::Schema::GROUPS.each do |group|
        assert_match(/\.schema-rel__dot--#{Regexp.escape(group)}\s*\{/, scss,
                     "stylesheet has no `.schema-rel__dot--#{group}` rule for Schema::GROUPS entry '#{group}'")
      end
    end

    # …and the other direction, so a group that is dropped from GROUPS does not
    # leave an orphaned rule behind that looks like it is still in use.
    test 'the stylesheet defines no dot modifier outside the declared groups' do
      modifiers = SCSS_PATH.read.scan(/\.schema-rel__dot--([a-z-]+)\s*\{/).flatten.uniq

      assert_empty modifiers - DataCycleCore::Schema::GROUPS
    end

    # The dependency graph feeds the same definition into rows, targets and nodes;
    # the payload the JS component receives must therefore never carry a raw
    # content_type.
    test 'the dependency graph payload only carries declared groups' do
      graph = DataCycleCore::Schema::DependencyGraph.new(
        schema: DataCycleCore::Schema.load_schema_from_database,
        locale: I18n.default_locale,
        thing_counts: {},
        overlay_names: []
      )

      groups = graph.to_graph[:nodes].pluck(:group) +
               graph.rows.pluck(:group) +
               graph.rows.flat_map { |row| row[:connections] }.flat_map { |c| c[:targets] }.pluck(:group)

      assert_empty groups.uniq - DataCycleCore::Schema::GROUPS
    end
  end
end
