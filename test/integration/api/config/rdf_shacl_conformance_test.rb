# frozen_string_literal: true

require 'v4/base'
require 'shacl'
require 'json/ld'

module DataCycleCore
  module Api
    module Config
      # Regression guard for the SHACL feature (#50196): nothing else in the shipped
      # code reads the generated shapes back, so without this a drift between them and
      # the delivered data would go unnoticed. `shacl` sits in GemfileCore's :test group
      # for this one test; Rdf::ShapesBuilder writes the shapes through ::RDF terms and
      # never loads the gem. Runs the real gem against a real v4 JSON-LD export.
      #
      # A SINGLE-content export cannot be fully self-closed, so two violation
      # categories are expected and explicitly tolerated — this test owns that rule,
      # and guides/rdf_schema_api.md describes the same case for API consumers:
      #   1. reference stubs — a linked content/image appears only as {@id,@type};
      #      sh:targetClass matches every typed node, so its own required fields are
      #      reported missing. The target is fully described in ITS OWN export.
      #   2. non-inlinable sh:class values — a classification/linked value that is
      #      delivered as a bare literal (e.g. cc:license as the CC-URI string) or as
      #      an {@id,@type} stub can never satisfy sh:class in a single export.
      # Everything else (datatype / cardinality drift on a delivered property) fails.
      class RdfShaclConformanceTest < DataCycleCore::V4::Base
        CLASS_COMPONENT = 'http://www.w3.org/ns/shacl#ClassConstraintComponent'
        MIN_COUNT_COMPONENT = 'http://www.w3.org/ns/shacl#MinCountConstraintComponent'

        before(:all) do
          @content = DataCycleCore::V4::DummyDataHelper.create_data('full_poi')
        end

        # Built once — building + compiling the shapes is expensive.
        def self.shapes_graph
          @shapes_graph ||= DataCycleCore::Rdf::ShapesBuilder.new.call
        end

        def self.shapes
          @shapes ||= SHACL.get_shapes(shapes_graph)
        end

        # sh: vocabulary term.
        def sh(term)
          DataCycleCore::Rdf::Namespaces.vocabulary('sh')[term]
        end

        # Parse a v4 JSON-LD export (inline @context + @graph) into an RDF graph.
        def export_graph(jsonld)
          graph = ::RDF::Graph.new
          graph << ::JSON::LD::API.toRdf(jsonld)
          graph
        end

        # A node the export only references (carries rdf:type but no delivered
        # properties) — the single-export reference-stub artifact.
        def stub_node?(node, data)
          statements = data.query([node, nil, nil]).to_a
          statements.any? && statements.all? { |st| st.predicate == ::RDF.type }
        end

        # True for the two documented single-export artifacts (see class comment), so
        # only genuine shape/export drift remains.
        def single_export_artifact?(result, data)
          return true if stub_node?(result.focus, data)
          return false unless result.component.to_s == CLASS_COMPONENT

          # sh:class is unsatisfiable in a single export when the value is a bare
          # literal or an {@id,@type} stub (the typed target is not inlined here).
          result.value.is_a?(::RDF::Literal) || stub_node?(result.value, data)
        end

        test 'the delivered v4 JSON-LD export conforms to the generated SHACL shapes (apart from single-export artifacts)' do
          post api_v4_thing_path(id: @content.id)

          assert_response :success

          data = export_graph(response.parsed_body)

          assert_operator data.count, :>, 0, 'expected the delivered export to produce triples'

          report = self.class.shapes.execute(data)
          unexpected = report.results.reject { |result| single_export_artifact?(result, data) }

          assert_empty unexpected.map(&:to_s),
                       "delivered export has unexpected SHACL violations (shapes/export drift):\n#{unexpected.join("\n\n")}"
        end

        # Negative control: proves the validator is not a no-op that passes everything.
        # A node typed as a class whose shape requires a property, delivered without
        # that property, MUST be reported — otherwise the positive test above is
        # meaningless. Derived from the shapes so it adapts to the instance.
        test 'the SHACL validator rejects data that violates a required constraint' do
          raw = self.class.shapes_graph

          required_shape = raw.query([nil, ::RDF.type, sh(:NodeShape)]).map(&:subject).find do |node_shape|
            raw.query([node_shape, sh(:property), nil]).any? do |property|
              raw.query([property.object, sh(:minCount), nil]).any? { |m| m.object.to_i >= 1 }
            end
          end

          assert required_shape, 'expected at least one NodeShape with a required (sh:minCount) property'

          target_class = raw.query([required_shape, sh(:targetClass), nil]).first.object
          data = ::RDF::Graph.new
          data << ::RDF::Statement(::RDF::URI('urn:datacycle:test:incomplete'), ::RDF.type, target_class)

          report = self.class.shapes.execute(data)

          assert_not report.conform?, 'a node missing its required properties must not conform'
          assert report.results.any? { |result| result.component.to_s == MIN_COUNT_COMPONENT },
                 'expected a sh:minCount violation for the missing required property'
        end
      end
    end
  end
end
