# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Mcp
    # Assertions that must hold for EVERY tool -- iterated over the registry rather than repeated per
    # tool, so a newly added tool cannot slip past them silently.
    class ToolContractTest < DataCycleCore::TestCases::ActiveSupportTestCase
      ALL_TOOLS = (
        DataCycleCore::Mcp::Servers::GlobalServer::TOOLS +
        DataCycleCore::Mcp::Servers::SingleEndpointServer::TOOLS +
        DataCycleCore::Mcp::Servers::Base::WRITE_TOOLS
      ).uniq.freeze

      # Every language this installation carries -- not hard-coded to [:de, :en]: an instance with a
      # third language should see its untranslated descriptions HERE and not first at the client.
      def locales = I18n.available_locales
      CONDITION_OPERATORS = [:in, :not_in].freeze

      # The limit parameters derived from the OpenAPI document: tool => OpenAPI operation.
      OPENAPI_LIMIT_TOOLS = {
        DataCycleCore::Mcp::Tools::Suggest => 'suggestEndpoint',
        DataCycleCore::Mcp::Tools::SuggestByTitle => 'suggestEndpointByTitle'
      }.freeze

      # Without this boundary a mistyped parameter name is a no-op rather than an error:
      # "template_name" instead of "template_names" filters nothing, and search_contents answers with
      # the endpoint's total -- read as an answer, a massively inflated number.
      test 'every tool rejects unknown arguments' do
        offenders = ALL_TOOLS.reject { |tool| tool.input_schema[:additionalProperties] == false }

        assert_empty offenders.map(&:tool_name), 'input_schema root must set additionalProperties: false'
      end

      test 'every tool has a name and a resolvable description' do
        ALL_TOOLS.each do |tool|
          assert_predicate tool.tool_name, :present?
          locales.each do |locale|
            description = tool.description(locale:, endpoint_name: 'Testendpoint')

            assert_predicate description, :present?
            assert_not_includes description, 'translation missing', "#{tool.tool_name} (#{locale})"
          end
        end
      end

      # The attribute condition is the only place where a schema-conformant input could still filter
      # nothing ("in": {}) -- hence minProperties in addition to the server-side check in
      # Mcp::AttributeFilter#build_filters.
      test 'attribute conditions cannot be empty' do
        condition = DataCycleCore::Mcp::Tools::SearchContents.input_schema.dig(:properties, :attributes, :items)

        # slice rather than refute: refute(nil) would be green although the keyword is then not set
        # at all.
        assert_equal({ additionalProperties: false }, condition.slice(:additionalProperties))
        CONDITION_OPERATORS.each do |key|
          assert_equal({ minProperties: 1, additionalProperties: false }, condition.dig(:properties, key).slice(:minProperties, :additionalProperties), key)
        end
      end

      # A concept NAME instead of the UUID ("wandern" rather than the alias id) is the likeliest LLM
      # mistake at these parameters, and items: {type: 'string'} invites it. Without the declaration
      # it is not a schema error but runs all the way into the query -- in Mcp::FilterDescription
      # into a ::uuid[] cast that aborts with a PG::InvalidTextRepresentation instead of saying what
      # to change.
      #
      # Over the registry and not per tool, so a newly added id parameter cannot slip past the
      # declaration (the same argument as for additionalProperties above). The pattern catches BOTH
      # spellings -- `ids` without a prefix as well as `content_ids` -- because the first cut
      # (/_ids\z/) let 9 of the 13 id parameters through unnoticed: the singular `id`/`*_id` ones and
      # select_things' `ids`.
      ID_PARAMETER_NAME = /(\A|_)ids?\z|_id_groups\z/
      test 'every id parameter declares the uuid form' do
        offenders = ALL_TOOLS.flat_map do |tool|
          tool.input_schema[:properties].to_h.filter_map do |name, property|
            next unless name.to_s.match?(ID_PARAMETER_NAME)

            # slice rather than an individual assertion: it checks along that the length bounds are
            # there -- without them the pattern does not keep the promise (see Mcp::UUID_CONSTRAINTS).
            constraints = value_schema(property).slice(*DataCycleCore::Mcp::UUID_CONSTRAINTS.keys)

            "#{tool.tool_name}.#{name}" unless constraints == DataCycleCore::Mcp::UUID_CONSTRAINTS
          end
        end

        assert_empty offenders, "id parameters must declare format: 'uuid' (Tools::Base.enforce_uuid_format turns it into an enforceable assertion); an id that is NOT a UUID belongs out of ID_PARAMETER_NAME with a reason"
      end

      # The declaration in the tool schema is format: 'uuid'; it only takes effect through the
      # centrally added pattern/minLength/maxLength. Checked against a throwaway tool rather than the
      # real ones, because what has to be covered here are the DEPTHS: nested objects and the array
      # of arrays each occur only once in the real set, and a lost recursion level would not be
      # recognisable from outside as a missing check.
      test 'input_schema turns format uuid into an enforceable assertion at every depth' do
        properties = uuid_format_probe_tool.input_schema[:properties]

        assert_equal DataCycleCore::Mcp::UUID_CONSTRAINTS, properties[:id].slice(*DataCycleCore::Mcp::UUID_CONSTRAINTS.keys)
        assert_equal DataCycleCore::Mcp::UUID_CONSTRAINTS, properties.dig(:ids, :items).slice(*DataCycleCore::Mcp::UUID_CONSTRAINTS.keys)
        assert_equal DataCycleCore::Mcp::UUID_CONSTRAINTS, properties.dig(:id_groups, :items, :items).slice(*DataCycleCore::Mcp::UUID_CONSTRAINTS.keys)
        assert_equal DataCycleCore::Mcp::UUID_CONSTRAINTS, properties.dig(:nested, :properties, :id).slice(*DataCycleCore::Mcp::UUID_CONSTRAINTS.keys)
        # A parameter without the declaration stays untouched, and a narrower shape of its own wins.
        assert_not properties[:name].key?(:pattern)
        assert_equal '^dc-', properties.dig(:prefixed_id, :pattern)
      end

      # The shipped assertion (Mcp::UUID_CONSTRAINTS) and the server-side check in Ruby
      # (String#uuid?, applied in Mcp::FilterDescription#descendant_ids_for) are two representations
      # of the same shape -- one as an ECMA-262 string for JSON Schema, one as a Ruby regexp. They
      # MUST accept the same inputs, or one is a promise the other does not keep. This test is the
      # reason the MCP layer may carry its own representation without being a drifting duplicate.
      #
      # Checked through the mcp gem rather than against Regexp.new(pattern), because only its
      # compilation makes the difference at issue here: json_schemer translates the pattern into a
      # RUBY regexp, where ^ and $ are LINE anchors. "wandern\n<uuid>" therefore satisfies
      # "^<uuid>$" and got through the schema before the length bounds existed.
      test 'the shipped uuid assertion and the ruby side check accept the same values' do
        uuid = SecureRandom.uuid
        accepted = [uuid, uuid.upcase]
        rejected = ['wandern', '', uuid.delete('-'), "#{uuid} ", "x#{uuid}", "wandern\n#{uuid}", "#{uuid}\nwandern"]

        accepted.each do |value|
          assert_nothing_raised { validate_uuid_argument(value) }
          assert_predicate value, :uuid?
        end

        rejected.each do |value|
          assert_raises(MCP::Tool::InputSchema::ValidationError, value.inspect) { validate_uuid_argument(value) }
          assert_not_predicate value, :uuid?
        end
      end

      # Tool descriptions go to every installation. A measurement from ONE instance set in concrete
      # there is therefore wrong for every other and goes stale here with the next import -- the
      # tools supply the numbers at runtime (count, largest_single_variant_count, coverage, explain).
      test 'tool descriptions carry no measured instance counts' do
        offenders = []

        locales.each do |locale|
          I18n.t('mcp.tools', locale:).each do |key, value|
            next if value[:description].blank?

            offenders << "#{locale}.#{key}" if value[:description].match?(/(gemessen|measured)[^.]*\d{2,}/i)
          end
        end

        assert_empty offenders, 'measured counts belong in code comments/docs, not in shipped descriptions'
      end

      # A limit parameter's default belongs in the schema as a JSON Schema `default` -- that is where
      # Base#limit_from reads it at runtime AND the client reads it up front. Without it, limit_from
      # falls to an error rather than to nil.to_i == 0, but only at call time: this assertion pulls
      # that forward to test time and prevents the value from migrating back into #call as a literal.
      test 'every tool with a limit declares its default in the schema' do
        with_limit = ALL_TOOLS.select { |tool| tool.input_schema.dig(:properties, :limit).present? }
        offenders = with_limit.reject { |tool| tool.default_limit.is_a?(Integer) }

        assert_empty offenders.map(&:tool_name), 'limit property must carry an integer JSON-Schema default'
      end

      # A limit of 0 is the second half of the same trap as a missing default: the call succeeds, the
      # hit list is empty, and that is indistinguishable from the result "nothing found" -- exactly
      # the reasoning with which Base#limit_from raises on a missing default. An LLM client that
      # computes a limit does hit 0 (or a negative number).
      #
      # The boundary belongs in the SCHEMA and not in #call: there the mcp gem rejects it with an
      # error message before the tool runs, and the client sees the rule up front. The limit
      # parameters derived from the OpenAPI document (suggest, suggest_by_title) carry minimum: 1
      # anyway -- this assertion brings the MCP-owned declarations up to that.
      test 'every tool with a limit declares a lower bound of at least one' do
        with_limit = ALL_TOOLS.select { |tool| tool.input_schema.dig(:properties, :limit).present? }

        assert_operator with_limit.size, :>, 0, 'expected some tools to take a limit'

        offenders = with_limit.reject { |tool| tool.input_schema.dig(:properties, :limit, :minimum).to_i >= 1 }

        assert_empty offenders.map(&:tool_name), 'limit property must declare minimum: 1 -- limit 0 returns an empty list that reads like "nothing found"'
      end

      # The actual drift guard: on these tools the limit schema comes from the OpenAPI document
      # (openapi_property), so the applied default has to be the same. Previously it was a
      # hand-copied second version -- a changed OpenAPI default would have had the tool name the new
      # value and apply the old one, without an error.
      test 'openapi-derived limit defaults match the OpenAPI document' do
        document = DataCycleCore::Mcp::Document.new

        OPENAPI_LIMIT_TOOLS.each do |tool, operation_id|
          expected = document.path_parameter_schema(operation_id, 'limit')&.dig('default')

          assert_predicate expected, :present?, "OpenAPI operation #{operation_id} lost its limit default"
          assert_equal expected, tool.default_limit, "#{tool.tool_name} applies a different limit default than #{operation_id} declares"
        end
      end

      # tool_name and description_key were the same, doubly declared string in every tool. After the
      # unification Base#description_key derives it -- this assertion pins that a tool without a
      # declaration of its own still finds its locale entry.
      test 'description_key defaults to the tool_name' do
        ALL_TOOLS.each do |tool|
          assert_equal tool.tool_name, tool.description_key, "#{tool.tool_name} resolves an unexpected description_key"
        end
      end

      # The argument descriptions used to sit as German literals in the Ruby code and were thereby
      # the only client-visible texts of the server that could not be translated. Checked over the
      # registry and both locales, so a new argument cannot get through without a locale entry: the
      # mistake is not recognisable from the result, because "translation missing: ..." stands in the
      # place of a description and an LLM reads it as one.
      test 'every tool argument description resolves in every locale' do
        offenders = []

        ALL_TOOLS.each do |tool|
          locales.each do |locale|
            schema_descriptions(tool.input_schema(locale:)).each do |path, description|
              offenders << "#{locale}.#{tool.tool_name}.#{path}" if description.blank? || description.include?('translation missing')
            end
          end
        end

        assert_empty offenders
      end

      # The schema cache hung off ONE slot (@input_schema ||=) and thereby froze the language to that
      # of the first access in the process -- which language a worker served depended on which
      # request hit it first. Both are checked: that the language takes effect and that caching still
      # happens (building costs the OpenAPI DocumentBuilder).
      test 'a tool schema is built per locale and cached per locale' do
        tool = DataCycleCore::Mcp::Tools::SearchContents

        assert_not_equal(
          tool.input_schema(locale: :de).dig(:properties, :query, :description),
          tool.input_schema(locale: :en).dig(:properties, :query, :description)
        )
        assert_same tool.input_schema(locale: :de), tool.input_schema(locale: :de)
        assert_not_same tool.input_schema(locale: :de), tool.input_schema(locale: :en)
      end

      # Names of import sources and classification trees of ONE installation. Naming them in a
      # shipped tool description makes the statement wrong for every other installation -- and
      # unnoticed at that, because nothing simply matches there.
      INSTANCE_MARKERS = /Feratel|Bergfex|Kategoriebaum/
      private_constant :INSTANCE_MARKERS

      # What is NOT forbidden here: place names in example QUESTIONS ("in Gemeinde Egg"). Those
      # illustrate the shape of a question and claim nothing about the data. What is forbidden are
      # the identifiers a concrete installation hangs off.
      #
      # Instance knowledge belongs in api.mcp.instance_notes instead (which hangs off the server
      # instructions) or, for a single endpoint, in its description, which list_endpoints delivers.
      test 'no shipped description claims facts about one installation' do
        offenders = []

        locales.each do |locale|
          I18n.t('mcp.tools', locale:).each do |key, value|
            offenders << "#{locale}.#{key}" if value[:description]&.match?(INSTANCE_MARKERS)

            value[:arguments].to_h.each do |argument, text|
              offenders << "#{locale}.#{key}.#{argument}" if text.is_a?(String) && text.match?(INSTANCE_MARKERS)
            end
          end
        end

        assert_empty offenders, 'instance-specific names belong in api.mcp.instance_notes, not in a shipped description'
      end

      # Descriptions must not fix a language the code does not keep to: without a locale argument,
      # suggest and suggest_by_title fell back to the literal 'de' while the description promised the
      # session language -- a mount asked for 'en' silently returned suggestions from the German
      # index. Checked over the registry, because the same mistake can recur in every tool with a
      # language argument.
      #
      # The fallback belongs exclusively in Base#locale_from (argument -> mount ->
      # I18n.default_locale): a fixed value in the gem is a silent false assumption on every
      # differently configured instance -- the query then runs against the index of a language the
      # endpoint does not carry and returns too few hits without erroring. That is why the pattern
      # catches every locale source, not only the argument.
      test 'no tool falls back to a hardcoded language' do
        offenders = ALL_TOOLS.select do |tool|
          # The source file from the class itself rather than through an assembled path: that would
          # hang on the directory location of the dummy app's Rails.root and break at the first move.
          source = File.read(tool.instance_method(:call).source_location.first)
          source.match?(/\[:locale\][^\n]*\|\|\s*['"][a-z]{2}['"]/)
        end

        assert_empty offenders.map(&:tool_name), 'locale fallbacks belong on #locale_from, not on a literal'
      end

      # The tools that announce a write. A guard rather than a second list: the read case is the
      # DEFAULT (Tools::Publication::DEFAULT_ANNOTATIONS), so a new writing tool without its own declaration
      # announces itself as read-only -- which invites a client to call it unasked. Entered here, a
      # third one has to pass a reviewer. list_writable_attributes is deliberately absent although it
      # ships with the write tools: it only reads.
      WRITING_TOOLS = [
        DataCycleCore::Mcp::Tools::CreateContent,
        DataCycleCore::Mcp::Tools::UpdateContent
      ].freeze
      private_constant :WRITING_TOOLS

      test 'only the writing tools are annotated as writing' do
        writing = ALL_TOOLS.reject { |tool| tool.annotations[:read_only_hint] }

        assert_equal WRITING_TOOLS.map(&:tool_name).sort, writing.map(&:tool_name).sort
      end

      # The declaration is worthless if to_mcp_tool drops it on the way to MCP::Tool -- the seam at
      # which the transport silently discarded its headers. update_content, because it is the tool
      # whose hints differ from the gem's own defaults in both directions.
      test 'annotations and the output schema reach the published tool' do
        published = DataCycleCore::Mcp::Tools::UpdateContent.to_mcp_tool(description: 'Test').to_h

        assert_equal(
          { destructiveHint: true, idempotentHint: true, openWorldHint: false, readOnlyHint: false },
          published[:annotations]
        )
        # The envelope is worth nothing to a client that is not told about it: outputSchema is how
        # tools/list announces it, and BaseTest's envelope assertion would stay green without it.
        assert_equal ['ok', 'data'], published.dig(:outputSchema, :required)
      end

      private

      # The node describing the shape of ONE value: for a scalar the property itself, for an array
      # its items -- and for classification_alias_id_groups (an array of arrays) the items two levels
      # down. to_h so that an array without items does not abort here with a NoMethodError but is
      # reported as a violation.
      def value_schema(property)
        schema = property
        schema = schema[:items].to_h while schema[:type] == 'array'
        schema
      end

      # A tool that exists only for the depth test: it declares format: 'uuid' at every level it
      # occurs at in real schemas, plus the two counter-checks (without a declaration, and with a
      # narrower shape of its own).
      def uuid_format_probe_tool
        Class.new(DataCycleCore::Mcp::Tools::Base) do
          self.tool_name = 'uuid_format_probe'
          input_schema do
            {
              type: 'object',
              properties: {
                id: { type: 'string', format: 'uuid' },
                ids: { type: 'array', items: { type: 'string', format: 'uuid' } },
                id_groups: { type: 'array', items: { type: 'array', items: { type: 'string', format: 'uuid' } } },
                nested: { type: 'object', properties: { id: { type: 'string', format: 'uuid' } } },
                name: { type: 'string' },
                prefixed_id: { type: 'string', format: 'uuid', pattern: '^dc-' }
              }
            }
          end
        end
      end

      # Validates a single value exactly as the MCP server validates the tool arguments.
      def validate_uuid_argument(value)
        MCP::Tool::InputSchema
          .new({ type: 'object', properties: { id: { type: 'string', format: 'uuid' }.reverse_merge(DataCycleCore::Mcp::UUID_CONSTRAINTS) } })
          .validate_arguments({ 'id' => value })
      end

      # { "properties.path" => description } across the whole schema, items and nested objects
      # included -- search_contents' attribute condition sits two levels down.
      def schema_descriptions(node, path = [], out = {})
        return out unless node.is_a?(Hash)

        out[path.join('.')] = node[:description] if node.key?(:description) && path.any?
        node[:properties]&.each { |name, child| schema_descriptions(child, path + [name], out) }
        schema_descriptions(node[:items], path + ['items'], out)

        out
      end
    end
  end
end
