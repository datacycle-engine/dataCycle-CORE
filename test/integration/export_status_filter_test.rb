# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Rendering coverage for the export_status advanced filter (#51495): the two partials, the shared
  # option helper and the locale keys, exercised through the endpoints the dashboard actually calls
  # when a filter is added (add_filter) and when its chip is rebuilt (add_tag_group).
  class ExportStatusFilterTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    setup do
      sign_in(DataCycleCore::User.find_by(email: 'admin@datacycle.at'))
      @exporting_system = DataCycleCore::ExternalSystem.create!(
        name: 'Exporting-System',
        identifier: 'exporting-system',
        config: { 'export_config' => { 'foo' => 'bar' } }
      )
    end

    test 'add_filter renders the export_status filter with both selectors' do
      post add_filter_path, params: { n: 'Export_status', t: 'export_status', m: 'i' }

      assert_response :success
      html = response.parsed_body['html']
      identifier = response.parsed_body['identifier']

      assert_includes html, I18n.t('filter.export_status', locale: :de)
      assert_includes html, "f[#{identifier}][t]"
      assert_includes html, "f[#{identifier}][v][external_system_ids][]"
      assert_includes html, "f[#{identifier}][v][status][]"
    end

    # The row has to read as the query it builds - "Export-Status | feratel | enthält nicht |
    # Erfolgreich" - because the mode negates the status alone, not the export.
    test 'the parts render as name, external system, mode, status' do
      post add_filter_path, params: { n: 'Export_status', t: 'export_status', m: 'i' }
      html = response.parsed_body['html']
      identifier = response.parsed_body['identifier']

      positions = [
        'advanced-filter-title',
        "f[#{identifier}][v][external_system_ids][]",
        "f[#{identifier}][m]",
        "f[#{identifier}][v][status][]"
      ].map { |needle| html.index(needle) }

      assert_equal positions.compact, positions, 'every part must be rendered'
      assert_equal positions.sort, positions, "parts out of order: #{positions.inspect}"
    end

    test 'the system selector offers systems with an export_config and no others' do
      post add_filter_path, params: { n: 'Export_status', t: 'export_status', m: 'i' }
      html = response.parsed_body['html']

      assert_includes html, @exporting_system.id
      # local-system carries an import config only, so it must not be selectable here
      assert_not_includes html, DataCycleCore::ExternalSystem.find_by(identifier: 'local-system').id
    end

    # export_status_subquery filters by the stored id without asking for an export_config, so a system
    # that has since lost one still narrows the result and still gets a chip. Were its option dropped,
    # options_for_select would render the select without it and the next submit would widen the query.
    test 'the system selector keeps a selected system that lost its export_config' do
      demoted = DataCycleCore::ExternalSystem.create!(name: 'Demoted-System', identifier: 'demoted-system')

      get root_path, params: {
        f: { '0' => {
          'c' => 'a', 'm' => 'i', 'n' => 'Export_status', 't' => 'export_status',
          'v' => { 'external_system_ids' => [demoted.id], 'status' => ['error'] }
        } }
      }, headers: { referer: root_path }

      assert_response :success
      assert_includes response.body, "value=\"#{demoted.id}\""
      # the systems that can export stay on offer next to it
      assert_includes response.body, "value=\"#{@exporting_system.id}\""
    end

    # Asserted through the translations, not the German copy, so relabelling an option stays a
    # locale-only change - what this guards is that every status reaches the selector with a label.
    test 'the status selector offers every sync status plus the no-status sentinel' do
      post add_filter_path, params: { n: 'Export_status', t: 'export_status', m: 'i' }
      html = response.parsed_body['html']

      (DataCycleCore::ExternalSystemSync::STATUSES + ['nil']).each do |status|
        label = I18n.t("filter.export_status_options.#{status}", locale: :de)

        assert_includes html, "<option value=\"#{status}\">#{label}</option>"
      end
    end

    test 'add_tag_group renders the chip with the selected system and status labels' do
      post add_tag_group_path, params: {
        f: { 'export-status-1' => {
          'n' => 'Export_status',
          't' => 'export_status',
          'm' => 'i',
          'v' => { 'external_system_ids' => [@exporting_system.id], 'status' => ['error', 'nil'] }
        } }
      }

      assert_response :success
      html = response.parsed_body['html']

      assert_includes html, I18n.t('filter.export_status', locale: :de)
      assert_includes html, "<span class=\"tag\">#{@exporting_system.name_with_types}</span>"
      ['error', 'nil'].each do |status|
        assert_includes html, "<span class=\"tag\">#{I18n.t("filter.export_status_options.#{status}", locale: :de)}</span>"
      end
      # a status the chip does not carry stays out of it
      assert_not_includes html, I18n.t('filter.export_status_options.success', locale: :de)
    end

    test 'add_tag_group renders a chip for a status-only selection' do
      post add_tag_group_path, params: {
        f: { 'export-status-1' => {
          'n' => 'Export_status',
          't' => 'export_status',
          'm' => 'e',
          'v' => { 'status' => ['success'] }
        } }
      }

      assert_response :success
      html = response.parsed_body['html']

      assert_includes html, "<span class=\"tag\">#{I18n.t('filter.export_status_options.success', locale: :de)}</span>"
      assert_not_includes html, @exporting_system.name_with_types
    end

    # add_tag_group is the live path: dashboard_filter.js posts it on every change to the open form, so
    # it has to reach the same verdict as the submitted dashboard below. Empty html is what makes the
    # javascript remove the chip again.
    test 'add_tag_group renders no chip while only an external system is selected' do
      post add_tag_group_path, params: {
        f: { 'export-status-1' => {
          'n' => 'Export_status',
          't' => 'export_status',
          'm' => 'i',
          'v' => { 'external_system_ids' => [@exporting_system.id] }
        } }
      }

      assert_response :success
      assert_empty response.parsed_body['html']
    end

    # A status list of blanks reaches this only from a stored filter's jsonb or a hand-built url - the
    # select emits no blank option - and export_status_values compact_blanks it away, so the query
    # narrows nothing either.
    test 'add_tag_group renders no chip for a status list of blanks' do
      post add_tag_group_path, params: {
        f: { 'export-status-1' => {
          'n' => 'Export_status',
          't' => 'export_status',
          'm' => 'i',
          'v' => { 'external_system_ids' => [@exporting_system.id], 'status' => [''] }
        } }
      }

      assert_response :success
      assert_empty response.parsed_body['html']
    end

    # Without a status the filter asks what external_system with type 'export' already answers, so
    # the dashboard drops it instead of showing a chip over a result it did not narrow.
    test 'the dashboard drops the filter when only an external system was selected' do
      get root_path, params: {
        f: { '0' => {
          'c' => 'a', 'm' => 'i', 'n' => 'Export_status', 't' => 'export_status',
          'v' => { 'external_system_ids' => [@exporting_system.id] }
        } }
      }, headers: { referer: root_path }

      assert_response :success
      # the rendered filter row, not the bare type name - that also appears as an option in the
      # "Filter hinzufügen" dropdown, which lists every available type regardless of what is active
      assert_not_includes response.body, 'data-label="export_status"'
    end

    # A url can submit a `v` that is not the Hash the partial builds, and a bare list of statuses
    # carries no 'status' key for the query to read, so it narrows nothing and gets no chip either.
    test 'the dashboard drops the filter when the value carries no readable status' do
      [['error'], 'error'].each do |value|
        get root_path, params: {
          f: { '0' => {
            'c' => 'a', 'm' => 'i', 'n' => 'Export_status', 't' => 'export_status', 'v' => value
          } }
        }, headers: { referer: root_path }

        assert_response :success
        assert_not_includes response.body, 'data-label="export_status"', "#{value.inspect} kept its chip"
      end
    end

    # The drop is keyed on the export_status type alone - no other filter is asked for a status.
    test 'a filter of another type without a status is left alone' do
      get root_path, params: {
        f: { '0' => {
          'c' => 'a', 'm' => 'i', 'n' => 'External_system', 't' => 'external_system',
          'q' => 'export', 'v' => [@exporting_system.id]
        } }
      }, headers: { referer: root_path }

      assert_response :success
      assert_includes response.body, 'data-label="external_system"'
    end

    test 'the dashboard keeps the filter once a status is selected' do
      get root_path, params: {
        f: { '0' => {
          'c' => 'a', 'm' => 'i', 'n' => 'Export_status', 't' => 'export_status',
          'v' => { 'external_system_ids' => [@exporting_system.id], 'status' => ['error'] }
        } }
      }, headers: { referer: root_path }

      assert_response :success
      assert_includes response.body, 'data-label="export_status"'
    end

    # A stored filter's parameters are jsonb and reach this unvalidated, so `v` need not be the Hash
    # the form builds. A shape with no status in it selects none, so the chip goes the same way as
    # the query - and nothing raises on the way there.
    test 'add_tag_group renders no chip for a value that is not a hash' do
      post add_tag_group_path, params: {
        f: { 'export-status-1' => {
          'n' => 'Export_status', 't' => 'export_status', 'm' => 'i', 'v' => ['not-a-hash']
        } }
      }

      assert_response :success
      assert_empty response.parsed_body['html']
    end
  end
end
