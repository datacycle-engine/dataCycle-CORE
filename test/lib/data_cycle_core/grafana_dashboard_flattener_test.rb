# frozen_string_literal: true

require 'test_helper'
require 'data_cycle_core/grafana_dashboard_flattener'

module DataCycleCore
  class GrafanaDashboardFlattenerTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'constant variables are substituted in every format' do
      result = flatten(
        dashboard_variables: [constant_variable('region_classification_tree', 'Administrative Einheiten')],
        sql: 'AND ctl.name = ${region_classification_tree:sqlstring} OR ctl.name = ${region_classification_tree:singlequote} OR ctl.name = ${region_classification_tree}'
      )

      assert_equal "AND ctl.name = 'Administrative Einheiten' OR ctl.name = 'Administrative Einheiten' OR ctl.name = Administrative Einheiten", sql_of(result)
    end

    test 'single quotes are escaped per format' do
      result = flatten(
        dashboard_variables: [constant_variable('tree', "Ober'st")],
        sql: '${tree:sqlstring} ${tree:singlequote} ${tree}'
      )

      assert_equal "'Ober''st' 'Ober\\'st' Ober'st", sql_of(result)
    end

    test 'a custom all value is inserted verbatim, without applying the format' do
      result = flatten(
        tab_variables: [
          query_variable('locales', all_value: "'__ALL__'", current: ['$__all']),
          query_variable('domain', all_value: '.+', current: ['$__all'])
        ],
        sql: 'ARRAY[${locales:singlequote}] ARRAY[${locales:sqlstring}] domain=~"${domain:regex}"'
      )

      assert_equal 'ARRAY[\'__ALL__\'] ARRAY[\'__ALL__\'] domain=~".+"', sql_of(result)
    end

    test 'a custom all value is used only while All is selected' do
      result = flatten(
        tab_variables: [query_variable('locales', all_value: "'__ALL__'", current: ['de'])],
        sql: 'ARRAY[${locales:singlequote}]'
      )

      assert_equal "ARRAY['de']", sql_of(result)
    end

    test 'a multi value selection is joined per format' do
      result = flatten(
        tab_variables: [query_variable('locales', current: ['de', 'en'])],
        sql: '${locales:singlequote} | ${locales:sqlstring} | ${locales:regex} | ${locales}'
      )

      assert_equal "'de','en' | 'de','en' | (de|en) | de,en", sql_of(result)
    end

    test 'regex format escapes special characters' do
      result = flatten(
        dashboard_variables: [constant_variable('domain', 'a.b-c')],
        sql: '${domain:regex}'
      )

      assert_equal 'a\.b\-c', sql_of(result)
    end

    test 'tab scoped variables are resolved and every variables array is emptied' do
      result = flatten(
        dashboard_variables: [constant_variable('datacycle_url', 'https://datenhafen.bodensee.eu')],
        tab_variables: [query_variable('locales', all_value: "'__ALL__'", current: ['$__all'])],
        sql: '${datacycle_url}/things ${locales:singlequote}'
      )

      assert_equal 'https://datenhafen.bodensee.eu/things \'__ALL__\'', sql_of(result)
      assert_empty result.dig('spec', 'variables')
      assert_empty result.dig('spec', 'layout', 'spec', 'tabs', 0, 'spec', 'layout', 'spec', 'rows', 0, 'spec', 'variables')
    end

    test 'bare dollar references are substituted' do
      result = flatten(
        dashboard_variables: [constant_variable('datacycle_url', 'https://datenhafen.bodensee.eu')],
        sql: 'see $datacycle_url for details'
      )

      assert_equal 'see https://datenhafen.bodensee.eu for details', sql_of(result)
    end

    test 'datasource macros are left untouched' do
      sql = '$__timeFilter(created_at) $__timeGroup(created_at, $__interval) $__interval_ms ${__from:date} ${__to:date} $__range $__all'
      result = flatten(dashboard_variables: [constant_variable('tree', 'x')], sql: sql)

      assert_equal sql, sql_of(result)
    end

    test 'an unknown placeholder aborts with its name' do
      error = assert_raises(DataCycleCore::GrafanaDashboardFlattener::Error) do
        flatten(dashboard_variables: [constant_variable('tree', 'x')], sql: 'AND a = ${unknown_thing:sqlstring}')
      end

      assert_includes error.message, 'unknown_thing'
    end

    test 'a variable without a value aborts with its name' do
      variable = constant_variable('tree', 'x')
      variable['spec'].delete('current')
      variable['spec'].delete('query')

      error = assert_raises(DataCycleCore::GrafanaDashboardFlattener::Error) do
        flatten(dashboard_variables: [variable], sql: 'AND a = ${tree}')
      end

      assert_includes error.message, 'tree'
    end

    test 'an all selection without a custom all value aborts' do
      error = assert_raises(DataCycleCore::GrafanaDashboardFlattener::Error) do
        flatten(tab_variables: [query_variable('endpoint', current: ['$__all'])], sql: 'AND name = ${endpoint:singlequote}')
      end

      assert_includes error.message, 'endpoint'
    end

    test 'an empty constant value is a valid value' do
      result = flatten(
        dashboard_variables: [constant_variable('dq_without_region', '')],
        sql: 'AND id = ${dq_without_region:sqlstring}'
      )

      assert_equal "AND id = ''", sql_of(result)
    end

    test 'a variable with nothing selected aborts with its name' do
      error = assert_raises(DataCycleCore::GrafanaDashboardFlattener::Error) do
        flatten(tab_variables: [query_variable('locales', current: [])], sql: 'ARRAY[${locales:singlequote}]')
      end

      assert_includes error.message, 'locales'
    end

    test 'a variable name used in two scopes aborts' do
      error = assert_raises(DataCycleCore::GrafanaDashboardFlattener::Error) do
        flatten(
          dashboard_variables: [constant_variable('locales', 'de')],
          tab_variables: [query_variable('locales', all_value: "'__ALL__'", current: ['$__all'])],
          sql: '${locales:singlequote}'
        )
      end

      assert_includes error.message, 'locales'
    end

    test 'an unsupported format aborts rather than shipping the placeholder' do
      error = assert_raises(DataCycleCore::GrafanaDashboardFlattener::Error) do
        flatten(dashboard_variables: [constant_variable('tree', 'x')], sql: '${tree:json}')
      end

      assert_includes error.message, 'json'
    end

    test 'the raw format joins without quoting' do
      result = flatten(
        tab_variables: [query_variable('locales', current: ['de', 'en'])],
        sql: '${locales:raw}'
      )

      assert_equal 'de,en', sql_of(result)
    end

    test 'a bare reference to no variable is passed through, the way Grafana passes it through' do
      result = flatten(dashboard_variables: [], sql: 'renamePattern: $1')

      assert_equal 'renamePattern: $1', sql_of(result)
    end

    test 'a constant takes its value from spec.query when the export carries no current' do
      variable = constant_variable('tree', 'Administrative Einheiten')
      variable['spec'].delete('current')

      result = flatten(dashboard_variables: [variable], sql: '${tree:sqlstring}')

      assert_equal "'Administrative Einheiten'", sql_of(result)
    end

    test 'variables that resolved to an empty string are named' do
      flattener = DataCycleCore::GrafanaDashboardFlattener.new(
        build_dashboard(
          dashboard_variables: [constant_variable('dq_without_region', ''), constant_variable('tree', 'x')],
          sql: '${dq_without_region:sqlstring} ${tree}'
        )
      )
      flattener.call

      assert_equal ['dq_without_region'], flattener.empty_variables
    end

    test 'bare references that name no variable are reported, capture groups and macros are not' do
      flattener = DataCycleCore::GrafanaDashboardFlattener.new(
        build_dashboard(
          dashboard_variables: [constant_variable('tree', 'x')],
          sql: 'renamePattern: $1, $locales, ${tree}, $__timeFilter(created_at)'
        )
      )
      flattener.call

      assert_equal ['$locales'], flattener.untouched_references
    end

    # Only the one version is understood: v2beta1 and v2alpha1 are served next to it and shape their
    # elements, layouts and variables differently, and a version that does not exist yet says nothing
    # about how it shapes them. dashboard.grafana.app/v20 is in here to catch a prefix match.
    test 'every apiVersion but the exact one aborts' do
      [
        'dashboard.grafana.app/v2beta1',
        'dashboard.grafana.app/v2alpha1',
        'dashboard.grafana.app/v1',
        'dashboard.grafana.app/v3',
        'dashboard.grafana.app/v20',
        'dashboards.grafana.app/v2',
        'v2',
        '',
        nil
      ].each do |api_version|
        dashboard = build_dashboard(dashboard_variables: [], sql: 'SELECT 1')
        dashboard['apiVersion'] = api_version

        error = assert_raises(DataCycleCore::GrafanaDashboardFlattener::Error, "#{api_version.inspect} was accepted") do
          DataCycleCore::GrafanaDashboardFlattener.new(dashboard).call
        end

        assert_includes error.message, DataCycleCore::GrafanaDashboardFlattener::API_VERSION
        assert_includes error.message, api_version if api_version.present?
      end
    end

    test 'a top level that is not a Hash aborts with what it was' do
      [[], [{ 'a' => 1 }], 123, nil, 'dashboard'].each do |dashboard|
        error = assert_raises(DataCycleCore::GrafanaDashboardFlattener::Error, "#{dashboard.inspect} was accepted") do
          DataCycleCore::GrafanaDashboardFlattener.new(dashboard).call
        end

        assert_includes error.message, dashboard.class.name
      end
    end

    test 'the text format substitutes the display text, which is what a panel title wants' do
      variable = {
        'kind' => 'CustomVariable',
        'spec' => { 'name' => 'aggregate_fn', 'current' => { 'text' => 'Average', 'value' => 'AVG(score_val::decimal)' } }
      }

      result = flatten(dashboard_variables: [variable], sql: '${aggregate_fn:text} Content Score, ${aggregate_fn}')

      assert_equal 'Average Content Score, AVG(score_val::decimal)', sql_of(result)
    end

    test 'the text format joins a multi value selection the way Grafana does' do
      variable = query_variable('locales', current: ['de', 'en'])
      variable['spec']['current']['text'] = ['Deutsch', 'English']

      result = flatten(tab_variables: [variable], sql: '${locales:text}')

      assert_equal 'Deutsch + English', sql_of(result)
    end

    test 'the text format of an All selection is its text, not the custom all value' do
      result = flatten(
        tab_variables: [query_variable('locales', all_value: "'__ALL__'", current: ['$__all'])],
        sql: 'ARRAY[${locales:singlequote}] for ${locales:text}'
      )

      assert_equal "ARRAY['__ALL__'] for All", sql_of(result)
    end

    test 'the spec.query fallback is for constants only, a query variable without a value aborts' do
      variable = query_variable('locales', current: ['de'])
      variable['spec'].delete('current')
      variable['spec']['query'] = 'SELECT DISTINCT locale FROM things'

      error = assert_raises(DataCycleCore::GrafanaDashboardFlattener::Error) do
        flatten(tab_variables: [variable], sql: '${locales:singlequote}')
      end

      assert_includes error.message, 'locales'
    end

    test 'a dashboard that is not schema v2 aborts' do
      error = assert_raises(DataCycleCore::GrafanaDashboardFlattener::Error) do
        DataCycleCore::GrafanaDashboardFlattener.new(
          { 'schemaVersion' => 42, 'uid' => 'abc123', 'title' => 'Analytics', 'templating' => { 'list' => [] } }
        ).call
      end

      assert_includes error.message, 'dashboard.grafana.app/v2'
    end

    test 'a repeat that references a variable aborts' do
      dashboard = build_dashboard(dashboard_variables: [constant_variable('locales', 'de')], sql: 'SELECT 1')
      dashboard.dig('spec', 'layout', 'spec', 'tabs', 0, 'spec', 'layout', 'spec', 'rows', 0, 'spec')['repeat'] =
        { 'mode' => 'variable', 'value' => 'locales' }

      error = assert_raises(DataCycleCore::GrafanaDashboardFlattener::Error) do
        DataCycleCore::GrafanaDashboardFlattener.new(dashboard).call
      end

      assert_includes error.message, 'locales'
    end

    test 'metadata identity is cleared so the clone imports as a new dashboard' do
      result = flatten(dashboard_variables: [], sql: 'SELECT 1')

      assert_empty result['metadata']
    end

    test 'the title is kept as it is, the clone lands in another org and folder' do
      result = flatten(dashboard_variables: [], sql: 'SELECT 1', title: 'dC Dashboard')

      assert_equal 'dC Dashboard', result.dig('spec', 'title')
    end

    test 'the input dashboard is left untouched' do
      dashboard = build_dashboard(dashboard_variables: [constant_variable('tree', 'x')], sql: '${tree}')

      DataCycleCore::GrafanaDashboardFlattener.new(dashboard).call

      assert_equal '${tree}', sql_of(dashboard)
      assert_equal 1, dashboard.dig('spec', 'variables').size
    end

    private

    def flatten(**)
      DataCycleCore::GrafanaDashboardFlattener.new(build_dashboard(**)).call
    end

    def build_dashboard(dashboard_variables: [], tab_variables: [], sql: '', title: 'Analytics')
      {
        'apiVersion' => 'dashboard.grafana.app/v2',
        'kind' => 'Dashboard',
        'metadata' => {
          'name' => 'ot9m7zs',
          'namespace' => 'default',
          'uid' => '2688912f-2175-46db-9433-731c8979eaf5',
          'resourceVersion' => '1778053702235984'
        },
        'spec' => {
          'title' => title,
          'variables' => dashboard_variables,
          'elements' => {
            'panel-1' => {
              'kind' => 'Panel',
              'spec' => {
                'data' => {
                  'spec' => {
                    'queries' => [
                      { 'spec' => { 'query' => { 'spec' => { 'rawSql' => sql } } } }
                    ]
                  }
                }
              }
            }
          },
          'layout' => {
            'kind' => 'TabsLayout',
            'spec' => {
              'tabs' => [
                {
                  'spec' => {
                    'title' => 'Sprachen',
                    'layout' => {
                      'kind' => 'RowsLayout',
                      'spec' => { 'rows' => [{ 'spec' => { 'variables' => tab_variables } }] }
                    }
                  }
                }
              ]
            }
          }
        }
      }
    end

    def constant_variable(name, value)
      {
        'kind' => 'ConstantVariable',
        'spec' => { 'name' => name, 'query' => value, 'current' => { 'text' => value, 'value' => value } }
      }
    end

    def query_variable(name, all_value: nil, current: ['All'])
      spec = { 'name' => name, 'current' => { 'text' => ['All'], 'value' => current }, 'multi' => true, 'includeAll' => true }
      spec['allValue'] = all_value if all_value

      { 'kind' => 'QueryVariable', 'spec' => spec }
    end

    def sql_of(dashboard)
      dashboard.dig('spec', 'elements', 'panel-1', 'spec', 'data', 'spec', 'queries', 0, 'spec', 'query', 'spec', 'rawSql')
    end
  end
end
