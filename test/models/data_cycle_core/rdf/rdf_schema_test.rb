# frozen_string_literal: true

require 'test_helper'
require 'rdf'

module DataCycleCore
  module Rdf
    # Structural tests for the generated RDF schema (#50196): the ontology (RDFS/OWL),
    # the SHACL shapes and the shared namespaces/serialization. Everything is derived
    # from the instance's ThingTemplates at runtime (no hard-coded template names) so
    # the suite is portable across instances. The graphs are built once per run.
    class RdfSchemaTest < ActiveSupport::TestCase
      # Memoized ontology graph.
      def ontology
        @@ontology ||= DataCycleCore::Rdf::OntologyBuilder.new.call # rubocop:disable Style/ClassVars
      end

      # Memoized SHACL shapes graph.
      def shapes
        @@shapes ||= DataCycleCore::Rdf::ShapesBuilder.new.call # rubocop:disable Style/ClassVars
      end

      # Vocabulary helper via the shared prefix map.
      def vocab(prefix)
        DataCycleCore::Rdf::Namespaces.vocabulary(prefix)
      end

      # Yields (template, thing, raw name, definition) for every delivered api-property,
      # using the same filter the builders use — the independent source for cross-checks.
      def each_api_property
        DataCycleCore::ThingTemplate.all.to_a.each do |template|
          thing = template.template_thing
          combined = thing.combined_property_names('v4')
          template.schema_sorted['properties'].each do |name, definition|
            next unless DataCycleCore::OpenApi::PropertyFilter.api_property?(thing, name, definition, combined:)

            yield template, thing, name, definition
          end
        end
      end

      # The named PropertyShape URI for a (template, api_name) — mirrors ShapesBuilder.
      def property_shape_uri(template, api_name)
        sanitize = ->(value) { DataCycleCore::Rdf::Terms.sanitize(value) }
        DataCycleCore::Rdf::Namespaces.dcls["#{sanitize.call(template.template_name)}Shape-#{sanitize.call(api_name)}"]
      end

      # All value constraints a PropertyShape carries: direct sh:datatype/sh:class/
      # sh:nodeKind plus the alternatives inside an sh:or list.
      def shape_range_uris(property_shape)
        sh = vocab('sh')
        nodes = [property_shape]
        shapes.query([property_shape, sh[:or], nil]).each do |solution|
          nodes.concat(::RDF::List.new(subject: solution.object, graph: shapes).to_a)
        end

        nodes.flat_map { |node|
          [sh[:datatype], sh[:class], sh[:nodeKind]].flat_map { |predicate| shapes.query([node, predicate, nil]).map { |s| s.object.to_s } }
        }.to_set
      end

      test 'namespaces are the single source of truth from the v4 @context' do
        all = DataCycleCore::Rdf::Namespaces.all

        ['dc', 'dcls', 'skos', 'dct', 'cc', 'odta', 'sdm', 'alps', 'schema'].each do |prefix|
          assert_predicate all[prefix], :present?, "missing instance prefix #{prefix}"
        end
        ['owl', 'rdf', 'rdfs', 'xsd', 'sh'].each do |prefix|
          assert_predicate all[prefix], :present?, "missing schema-language prefix #{prefix}"
        end
        assert_equal 'https://schema.datacycle.at/', all['dc']
        assert_equal 'https://schema.org/', all['schema']
      end

      test 'every ThingTemplate has its own owl:Class' do
        declared = ontology.query([nil, ::RDF.type, vocab('owl')[:Class]]).to_set { |s| s.subject.to_s }

        DataCycleCore::ThingTemplate.pluck(:template_name).each do |name|
          assert_includes declared, DataCycleCore::Rdf::Terms.dcls_class(name).to_s, "no owl:Class for #{name}"
        end
      end

      test 'every referenced dcls class/property is declared (no dangling references)' do
        dcls_base = DataCycleCore::Rdf::Namespaces.all['dcls']
        declared_classes = ontology.query([nil, ::RDF.type, vocab('owl')[:Class]]).to_set { |s| s.subject.to_s }

        # Every dcls: object used as a class (subClassOf/equivalentClass/domain/range/includes)
        # must be a declared owl:Class — e.g. api.type aliases like dcls:Angebot.
        class_predicates = [
          vocab('rdfs')[:subClassOf], vocab('owl')[:equivalentClass], vocab('rdfs')[:domain],
          vocab('rdfs')[:range], vocab('schema')[:domainIncludes], vocab('schema')[:rangeIncludes]
        ]
        referenced = class_predicates.flat_map { |predicate|
          ontology.query([nil, predicate, nil]).map { |s| s.object.to_s }
        }.select { |uri| uri.start_with?(dcls_base) }.to_set

        dangling = referenced - declared_classes

        assert_empty dangling, "dcls classes referenced but not declared: #{dangling.to_a.first(5)}"

        # Every SHACL sh:path is a predicate the instance actually delivers — the
        # @context-expansion of a delivered api_name (schema.org / dc / dcls / …), so the
        # shape validates the ABox. It is deliberately NOT the ontology's own dcls:
        # property URI, which the delivered data never uses.
        delivered = ::Set.new
        each_api_property do |_template, thing, name, _definition|
          api_name = thing.api_name_for(name) || name
          delivered << DataCycleCore::Rdf::Terms.delivered_property_uri(api_name).to_s
        end
        paths = shapes.query([nil, vocab('sh')[:path], nil]).to_set { |s| s.object.to_s }

        assert_empty(paths - delivered, 'sh:path values that are not a delivered predicate')
      end

      test 'classes carry schema.org superclasses and multilingual labels' do
        class_uris = ontology.query([nil, ::RDF.type, vocab('owl')[:Class]]).map(&:subject)

        with_schema_super = class_uris.any? do |uri|
          ontology.query([uri, vocab('rdfs')[:subClassOf], nil]).any? { |s| s.object.to_s.start_with?('https://schema.org/') }
        end

        assert with_schema_super, 'no class had a schema.org superclass'

        languages = ontology.query([nil, vocab('rdfs')[:label], nil]).map { |s| s.object.language }.uniq

        I18n.available_locales.each { |locale| assert_includes languages, locale, "no rdfs:label in #{locale}" }
      end

      test 'every property has a domain and a declared property type' do
        property_types = [vocab('owl')[:DatatypeProperty], vocab('owl')[:ObjectProperty], vocab('rdf')[:Property]]
        properties = property_types.flat_map { |type| ontology.query([nil, ::RDF.type, type]).map(&:subject) }.uniq

        assert_operator properties.count, :>, 0

        properties.each do |property|
          has_domain = ontology.query([property, vocab('rdfs')[:domain], nil]).any? ||
                       ontology.query([property, vocab('schema')[:domainIncludes], nil]).any?

          assert has_domain, "#{property} has no domain"
        end

        assert_predicate ontology.query([nil, vocab('rdfs')[:subPropertyOf], nil]), :any?, 'no schema.org subPropertyOf bridge'
      end

      test 'classification properties range over skos:Concept when present' do
        concept = vocab('skos')[:Concept]
        used_as_range = ontology.query([nil, vocab('rdfs')[:range], concept]).any? ||
                        ontology.query([nil, vocab('schema')[:rangeIncludes], concept]).any?
        used_anywhere = ontology.query([nil, nil, concept]).any?

        # skos:Concept must only ever appear as a property range (never a stray triple).
        assert_equal used_anywhere, used_as_range
      end

      test 'the ontology contains no blank nodes' do
        # NB: #count with a block is unreliable here (returns the total), so accumulate
        # the offending statements by hand instead of counting/selecting.
        blank = []
        ontology.each_statement { |statement| blank << statement if statement.subject.node? || statement.object.node? }

        assert_empty blank, 'the ontology should contain no blank nodes'
      end

      test 'one sh:NodeShape per ThingTemplate, each targeting a dcls class' do
        node_shapes = shapes.query([nil, ::RDF.type, vocab('sh')[:NodeShape]]).map(&:subject)

        assert_equal DataCycleCore::ThingTemplate.count, node_shapes.count

        dcls_base = DataCycleCore::Rdf::Namespaces.all['dcls']
        node_shapes.each do |shape|
          target = shapes.query([shape, vocab('sh')[:targetClass], nil]).first&.object

          assert target.to_s.start_with?(dcls_base), "#{shape} targets a non-dcls class"
        end
      end

      test 'SHACL cardinality matches the DataDefinitions (required, append, arrays)' do
        sh = vocab('sh')
        min_one = ::RDF::Literal(1)

        each_api_property do |template, thing, name, definition|
          api_name = thing.api_name_for(name) || name
          property_shape = property_shape_uri(template, api_name)

          assert_predicate shapes.query([property_shape, sh[:minCount], min_one]), :any?, "#{api_name} on #{template.template_name} is required but has no sh:minCount 1" if DataCycleCore::Rdf::PropertyMapping.required?(definition)

          # Array-valued properties (incl. append transformations) must NOT be capped.
          assert_empty shapes.query([property_shape, sh[:maxCount], nil]).to_a, "#{api_name} on #{template.template_name} is multi-valued but got sh:maxCount" if DataCycleCore::Rdf::PropertyMapping.multi_valued?(definition)
        end
      end

      test 'property ranges are constrained as the API actually delivers them' do
        each_api_property do |template, thing, name, definition|
          kind, ranges = DataCycleCore::Rdf::PropertyMapping.range_for(definition)
          next if ranges.empty?

          api_name = thing.api_name_for(name) || name
          declared = shape_range_uris(property_shape_uri(template, api_name))

          if kind == :object
            # Object ranges are constrained by the class IRI as delivered in @type
            # (schema.org via http; dcls/skos unchanged) — directly or as an sh:or member.
            ranges.each do |range|
              delivered = DataCycleCore::Rdf::Terms.delivered_class_uri(range).to_s

              assert_includes declared, delivered, "#{api_name} on #{template.template_name}: class range #{delivered} not constrained"
            end
          else
            # Literal ranges are delivery-translated (e.g. date/datetime -> schema:Date,
            # number -> xsd:integer|decimal, string -> langString), so the nominal xsd
            # type need not appear verbatim — but the value must be constrained as a literal.
            assert_not_empty declared, "#{api_name} on #{template.template_name}: literal range not constrained"
          end
        end
      end

      test 'literal datatypes use the forms the v4 API delivers' do
        xsd = vocab('xsd')
        delivered_date = DataCycleCore::Rdf::Terms.delivered_class_uri(vocab('schema')[:Date]).to_s

        seen_datetime = false
        each_api_property do |template, thing, name, definition|
          kind, ranges = DataCycleCore::Rdf::PropertyMapping.range_for(definition)
          next unless kind == :datatype && ranges.map(&:to_s).include?(xsd[:dateTime].to_s)

          seen_datetime = true
          api_name = thing.api_name_for(name) || name
          declared = shape_range_uris(property_shape_uri(template, api_name))

          assert_includes declared, delivered_date, "#{api_name} on #{template.template_name}: datetime not delivered as schema:Date"
          assert_not_includes declared, xsd[:dateTime].to_s, "#{api_name} on #{template.template_name}: nominal xsd:dateTime should not be a shape constraint"
        end

        assert seen_datetime, 'expected at least one datetime property to cross-check'
      end

      test 'no duplicate class, property or shape declarations' do
        sh = vocab('sh')

        # Template names must not collide into the same dcls class URI (sanitize collision).
        names = DataCycleCore::ThingTemplate.pluck(:template_name)
        class_uris = names.map { |name| DataCycleCore::Rdf::Terms.dcls_class(name).to_s }

        assert_equal names.uniq.size, class_uris.uniq.size, 'two templates map to the same owl:Class URI'

        # Each ontology property carries exactly one rdf:type (never both Datatype- and
        # ObjectProperty for the same api_name).
        property_types = [vocab('owl')[:DatatypeProperty], vocab('owl')[:ObjectProperty], vocab('rdf')[:Property]]
        property_subjects = property_types.flat_map { |type| ontology.query([nil, ::RDF.type, type]).map { |s| s.subject.to_s } }
        multi_typed = property_subjects.tally.select { |_uri, count| count > 1 }.keys

        assert_empty multi_typed, "properties with more than one rdf:type: #{multi_typed.first(5)}"

        # Each PropertyShape has exactly one sh:path (no two api_names collide onto one shape).
        path_counts = ::Hash.new(0)
        shapes.query([nil, sh[:path], nil]).each { |solution| path_counts[solution.subject.to_s] += 1 }
        multi_path = path_counts.select { |_shape, count| count > 1 }.keys

        assert_empty multi_path, "property shapes with more than one sh:path: #{multi_path.first(5)}"

        # Each NodeShape has exactly one sh:targetClass, and no two node shapes share a target.
        targets = shapes.query([nil, sh[:targetClass], nil]).map { |solution| [solution.subject.to_s, solution.object.to_s] }
        multi_target = targets.group_by(&:first).select { |_shape, list| list.size > 1 }.keys

        assert_empty multi_target, "node shapes with more than one sh:targetClass: #{multi_target.first(5)}"

        shared_target = targets.map(&:last).tally.select { |_uri, count| count > 1 }.keys

        assert_empty shared_target, "sh:targetClass shared by multiple node shapes: #{shared_target.first(5)}"
      end

      test 'every SHACL target and dcls class reference resolves to a declared owl:Class' do
        sh = vocab('sh')
        dcls_base = DataCycleCore::Rdf::Namespaces.all['dcls']
        declared = ontology.query([nil, ::RDF.type, vocab('owl')[:Class]]).to_set { |s| s.subject.to_s }

        targets = shapes.query([nil, sh[:targetClass], nil]).to_set { |s| s.object.to_s }

        assert_empty(targets - declared, 'sh:targetClass values without a declared owl:Class')

        # dcls: classes used as sh:class (linked/embedded ranges) must also be declared.
        dcls_classes = shapes.query([nil, sh[:class], nil]).to_set { |s| s.object.to_s }.select { |uri| uri.start_with?(dcls_base) }.to_set

        assert_empty(dcls_classes - declared, 'sh:class dcls references without a declared owl:Class')
      end

      test 'every serialization format round-trips losslessly' do
        [:turtle, :jsonld, :rdfxml, :ntriples].each do |format|
          output = DataCycleCore::Rdf::Serializer.serialize(ontology, format:)
          reparsed = ::RDF::Graph.new
          ::RDF::Reader.for(format).new(output) { |reader| reparsed << reader }

          assert_equal ontology.count, reparsed.count, "#{format} did not round-trip"
        end
      end

      test 'the @context document exposes every namespace prefix' do
        context = DataCycleCore::Rdf::ContextBuilder.new.call

        assert_equal DataCycleCore::Rdf::Namespaces.all, context['@context']
      end

      test 'cache keys are fingerprinted so template changes invalidate them' do
        key = DataCycleCore::Rdf::Cache.document_key(:ontology, :turtle)
        fingerprint = [DataCycleCore::ThingTemplate.maximum(:updated_at).to_i, DataCycleCore::ThingTemplate.count].join('-')

        assert_includes key, fingerprint
      end
    end
  end
end
