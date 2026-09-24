# frozen_string_literal: true

module DataCycleCore
  # Rewrites a schema-v2 Grafana dashboard (dashboard.grafana.app/v2) into a variable free clone
  # that can be shared externally.
  #
  # An externally shared dashboard performs no variable interpolation ("Variables and queries
  # including variables are not supported"), so every panel whose query carries a placeholder
  # reaches Postgres verbatim and fails with `syntax error at or near "$"` (SQLSTATE 42601). The
  # hidden ConstantVariables (`${region_classification_tree:sqlstring}`, 20x `${dq_*:sqlstring}`)
  # break the shared link just as the visible filters do, so resolving every placeholder to a
  # literal up front is what makes the link work at all.
  #
  # It runs in the middle of a three step procedure, of which steps 1 and 3 are done by hand in
  # Grafana's own UI so that neither dataCycle nor Grafana needs a credential for the other:
  #
  #   1. internal org, on the source dashboard: Export -> JSON, plain, *not* "for use in another
  #      instance" - that toggle swaps the datasource uids for ${DS_*} inputs and resets each
  #      variable's `current`, both of which this class reads.
  #   2. dataCycle, admin dashboard -> "Grafana-Dashboard umschreiben": upload that file, download
  #      the rewritten one (DashBoardController#flatten_grafana_dashboard).
  #   3. customer org: Import -> JSON, into the "Analytics" folder, then Share -> Share externally.
  #
  # The clone is generated once and then maintained by hand in the customer organization, so this
  # class aborts on anything it cannot resolve rather than shipping a half interpolated dashboard.
  class GrafanaDashboardFlattener
    class Error < StandardError
    end

    API_VERSION = 'dashboard.grafana.app/v2'
    VARIABLES_KEY = 'variables'

    # `${name}`, `${name:format}` and `$name`, the three forms Grafana interpolates.
    PLACEHOLDER = /\$(?:\{(?<braced>\w+)(?::(?<format>[\w:]+))?\}|(?<bare>\w+))/
    MACRO_PREFIX = '__'
    ALL_VALUE = '$__all'
    CAPTURE_REFERENCE = /\A\d+\z/
    CONSTANT_KIND = 'ConstantVariable'
    TEXT_FORMAT = 'text'

    # @param dashboard [Hash] the parsed JSON export; left untouched, #call returns a new tree
    def initialize(dashboard)
      @dashboard = dashboard
    end

    # @return [Hash] the flattened dashboard
    # @raise [Error] on a dashboard, placeholder or variable this class cannot resolve
    def call
      validate_api_version!
      @values = collect_values
      @untouched = []
      validate_repeats!

      substitute(@dashboard).tap do |result|
        # An import has to create a new dashboard rather than update the one the export came from,
        # and the customer organization knows none of the users, folders and ids named here:
        # metadata carries uid, name, resourceVersion, generation, creationTimestamp, the legacy
        # numeric id in labels["grafana.app/deprecatedInternalID"] and annotations naming the
        # source folder ("grafana.app/folder") and editors ("grafana.app/createdBy").
        result['metadata'] = {}
      end
    end

    # A dq_* constant nobody has filled in yet resolves to an empty string, which is a valid value
    # (the queries guard it with `NULLIF(${dq_x:sqlstring}, '') IS NULL`) but leaves its panel on
    # "Endpunkt nicht gesetzt" for good: the clone carries the empty literal, not the variable.
    #
    # @return [Array<String>] the variables that resolved to an empty string, after #call
    def empty_variables
      @values.to_h.select { |_name, value| (value[:verbatim] || value[:values].join).empty? }.keys
    end

    # A bare `$name` that names no variable is passed through, the way Grafana passes it through,
    # and a `$locales` that should have read `${locales}` is worth showing the operator, because it
    # reaches the customer's dashboard verbatim.
    #
    # A numeric one never is: `$1` in a renameByRegex transformation is the first capture group of
    # its own regex, `{"regex": "value (.*)", "renamePattern": "$1"}` in the dC Dashboard, which
    # renames the field `value de` to `de`. Grafana leaves those to the transformation, and
    # reporting them would put a line on every single run that means nothing.
    #
    # @return [Array<String>] the bare references left as they were, after #call
    def untouched_references
      @untouched.to_a.uniq.sort
    end

    private

    # The group serves v2 next to v2beta1 and v2alpha1, which name their elements, layouts and
    # variables differently, so only the version this class was written against is accepted: a
    # v2beta1 export has to fail loudly here rather than be half understood. Which version the
    # export dialog writes follows grafana's preferred version for the group, pinnable per instance
    # as [grafana-apiserver] preferred_api_version = dashboard.grafana.app/v2.
    def validate_api_version!
      raise Error, "expected a #{API_VERSION} dashboard export, got #{@dashboard.class}" unless @dashboard.is_a?(Hash)

      api_version = @dashboard['apiVersion'].to_s
      return if api_version == API_VERSION

      raise Error, "expected a #{API_VERSION} dashboard export, got apiVersion \"#{api_version}\""
    end

    # Variables live in a `variables` array, dashboard-wide under `spec` and again per tab and row.
    # Grafana resolves them per scope, this class resolves them once for the whole document, so a
    # name used in two scopes has to abort instead of letting one scope's value win everywhere.
    def collect_values
      each_variable.with_object({}) do |variable, values|
        name = variable.dig('spec', 'name')
        raise Error, "variable \"#{name}\" is defined in more than one scope" if values.key?(name)

        values[name] = resolved_value(variable)
      end
    end

    def each_variable(node = @dashboard, &)
      return to_enum(:each_variable, node) unless block_given?

      case node
      when Hash
        node.each do |key, value|
          next value.each(&) if variables?(key, value)

          each_variable(value, &)
        end
      when Array then node.each { |value| each_variable(value, &) }
      end
    end

    def variables?(key, value)
      key == VARIABLES_KEY && value.is_a?(Array)
    end

    # A custom all value is inserted verbatim: Grafana does not escape or format it either, and the
    # SQL relies on that - `ARRAY[${locales:singlequote}]` with the all value `'__ALL__'` has to
    # become `ARRAY['__ALL__']`, which the query then matches with `'__ALL__' = ANY(...)`. It only
    # applies while All is selected; an export saved with locales=[de] has to yield `'de'`.
    #
    # A ConstantVariable keeps its value twice, in `spec.query` and in `spec.current.value`, and
    # Grafana writes both - `query` is the fallback for an export that was assembled by hand. Only
    # for that kind: a QueryVariable's `query` is the SQL that produces its options, so falling back
    # to it there would substitute a SELECT statement as the variable's value.
    #
    # The display texts come along for the `text` format, which reads them rather than the values.
    #
    # @return [Hash] `{verbatim:}` for a custom all value, `{values:}` for a concrete selection,
    #   `{texts:}` alongside either
    def resolved_value(variable)
      spec = variable['spec'] || {}
      name = spec['name']
      current = spec['current']
      current = { 'value' => spec['query'] } if !current.is_a?(Hash) && variable['kind'] == CONSTANT_KIND && spec['query'].is_a?(String)
      raise Error, "variable \"#{name}\" carries no value to substitute" unless current.is_a?(Hash) && !current['value'].nil?

      values = Array.wrap(current['value']).map(&:to_s)
      raise Error, "variable \"#{name}\" has nothing selected" if values.empty?

      texts = Array.wrap(current['text']).map(&:to_s).presence || values
      return { values:, texts: } unless values.include?(ALL_VALUE)

      all_value = spec['allValue']
      raise Error, "variable \"#{name}\" is set to All but defines no custom all value" if all_value.blank?

      { verbatim: all_value, texts: }
    end

    # A repeat names its variable plainly (`repeat: {mode: variable, value: locales}`), so no
    # substitution reaches it, and the emptied `variables` array would leave it repeating over
    # nothing - the row or panel then disappears from the clone.
    def validate_repeats!
      repeated = each_repeat.filter_map { |repeat| repeat['value'] }.uniq & @values.keys
      return if repeated.empty?

      raise Error, "repeat over variable(s) #{repeated.join(', ')} cannot be flattened; resolve it in the dashboard first"
    end

    def each_repeat(node = @dashboard, &)
      return to_enum(:each_repeat, node) unless block_given?

      case node
      when Hash
        node.each do |key, value|
          next yield value if key == 'repeat' && value.is_a?(Hash)

          each_repeat(value, &)
        end
      when Array then node.each { |value| each_repeat(value, &) }
      end
    end

    def substitute(node)
      case node
      when Hash then node.to_h { |key, value| [key, variables?(key, value) ? [] : substitute(value)] }
      when Array then node.map { |value| substitute(value) }
      when String then substitute_string(node)
      else node
      end
    end

    # A datasource macro ($__timeFilter, $__interval, ${__from:date}) is interpolated by the
    # datasource at query time and has to survive untouched. An unknown `$name` in free text is
    # left alone the way Grafana leaves it, while an unknown `${name}` is the placeholder class
    # this clone must not ship and therefore aborts.
    def substitute_string(string)
      return string unless string.include?('$')

      string.gsub(PLACEHOLDER) do
        match = Regexp.last_match
        name = match[:braced] || match[:bare]
        value = @values[name]

        next match[0] if name.start_with?(MACRO_PREFIX)

        if value.nil? && match[:bare]
          @untouched << match[0] unless name.match?(CAPTURE_REFERENCE)
          next match[0]
        end

        raise Error, "no variable \"#{name}\" to substitute for \"#{match[0]}\"" if value.nil?

        formatted_value(value, match[:format], name)
      end
    end

    # `text` reads the display texts rather than the values, and applies to a custom all value too:
    # its `current.text` is "All", which is what Grafana renders there. The dC template dashboards
    # rely on this in panel titles - `${aggregate_fn:text} Content Score`, whose variable carries
    # `AVG(score_val::decimal)` as its value and "Average" as its text.
    def formatted_value(value, format, name)
      return value[:texts].join(' + ') if format == TEXT_FORMAT
      return value[:verbatim] if value[:verbatim]

      format_values(value[:values], format, name)
    end

    def format_values(values, format, name)
      case format
      when 'sqlstring' then values.map { |value| "'#{value.gsub("'", "''")}'" }.join(',')
      when 'singlequote' then values.map { |value| "'#{value.gsub("'") { "\\'" }}'" }.join(',')
      when 'regex' then regex_values(values)
      when nil, 'raw' then values.join(',')
      else raise Error, "unsupported format \"#{format}\" on variable \"#{name}\""
      end
    end

    def regex_values(values)
      escaped = values.map { |value| Regexp.escape(value) }

      escaped.size > 1 ? "(#{escaped.join('|')})" : escaped.first.to_s
    end
  end
end
