# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class AdditionalMenuLinkFeatureTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Feature::AdditionalMenuLink

    before(:all) do
      @config = DataCycleCore.features[:additional_menu_link].deep_dup
    end

    # DataCycleCore.features is frozen at the top level, so only nested keys can be written
    def teardown
      configure(@config[:links].deep_dup, enabled: @config[:enabled])
    end

    def configure(links, enabled: true)
      DataCycleCore.features[:additional_menu_link][:enabled] = enabled
      DataCycleCore.features[:additional_menu_link][:links] = links
      Subject.reload
    end

    test 'default configuration exposes grafana gated by its own permission' do
      grafana = Subject.links.find { |l| l.key == 'grafana' }

      assert_not_nil grafana
      assert_equal :grafana_dashboards, grafana.permission
      assert_not grafana.external?
    end

    test 'feature key resolves both ways' do
      assert_equal 'additional_menu_link', Subject.feature_key
      assert_equal Subject, DataCycleCore::Feature['additional_menu_link']
    end

    test 'links maps configured entries and defaults the icon' do
      configure({ 'grist' => { 'url' => 'https://grist.example.com/', 'icon' => 'table' }, 'plain' => { 'url' => 'https://plain.example.com/' } })

      grist, plain = Subject.links

      assert_equal ['grist', 'https://grist.example.com/', 'table'], [grist.key, grist.url, grist.icon]
      assert_nil grist.permission
      assert_equal 'external-link', plain.icon
    end

    test 'links skips entries without a url' do
      configure({ 'no_url' => { 'icon' => 'table' }, 'blank' => nil, 'ok' => { 'url' => '/somewhere' } })

      assert_equal ['ok'], Subject.links.map(&:key)
    end

    test 'links is empty while the feature is disabled' do
      configure({ 'grist' => { 'url' => 'https://grist.example.com/' } }, enabled: false)

      assert_not Subject.enabled?
      assert_empty Subject.links
    end

    test 'reload drops memoized links' do
      configure({ 'grist' => { 'url' => 'https://grist.example.com/' } })

      assert_equal ['grist'], Subject.links.map(&:key)

      configure({ 'typo3' => { 'url' => 'https://typo3.example.com/' } })

      assert_equal ['typo3'], Subject.links.map(&:key)
    end
  end
end
