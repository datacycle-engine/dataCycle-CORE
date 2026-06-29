# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Virtual
      class StringTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Virtual::String
        end

        test 'concat joins the configured parameters with the separator' do
          content = struct_double(given_name: 'Ada', family_name: 'Lovelace')

          value = subject.concat(virtual_parameters: ['given_name', 'family_name'], virtual_definition: { 'separator' => ' ' }, content:)

          assert_equal('Ada Lovelace', value)
        end

        test 'translation_by_imported_key returns the imported translation when it exists' do
          content = struct_double(template_name: 'POI', external_source: struct_double(identifier: 'outdooractive'), status_field: 'open')

          I18n.stub(:exists?, true) do
            I18n.stub(:t, 'Geöffnet') do
              value = subject.translation_by_imported_key(content:, virtual_parameters: ['status_field'])

              assert_equal('Geöffnet', value)
            end
          end
        end

        test 'translation_by_imported_key falls back to the raw value without a matching translation' do
          content = struct_double(template_name: 'POI', external_source: struct_double(identifier: 'outdooractive'), status_field: 'open')

          I18n.stub(:exists?, false) do
            assert_equal('open', subject.translation_by_imported_key(content:, virtual_parameters: ['status_field']))
          end
        end

        test 'license_uri reads the uri from cached collected classification contents' do
          license_alias = Class.new {
            def association_cached?(_key) = true
            def classification_alias_path = Struct.new(:full_path_ids).new([1, 2, 3])
            def classification_tree_label = Struct.new(:name).new('Lizenzen')
            def uri = 'https://cc.test/by/4.0'
          }.new
          ccc = Struct.new(:classification_alias) {
            def association_cached?(_key) = true
          }.new(license_alias)
          content = Struct.new(:collected_classification_contents) {
            def association_cached?(_key) = true
          }.new([ccc])

          assert_equal('https://cc.test/by/4.0', subject.license_uri(content:))
        end

        test 'to_additional_information builds embedded information things for present parameters' do
          template = Class.new {
            def template_missing? = false
            def dup = self

            def attributes=(_hash)
            end

            def set_memoized_attribute(_key, _value)
            end
          }.new
          ca_relation = Class.new {
            def for_tree(_tree) = self
            def with_internal_name(_name) = self
            def primary_classifications = ['info-type-1']
          }.new
          content = Class.new {
            def id = 'content-1'
            def try(_key) = 'A description'
            def properties_for(_key) = { 'label' => 'My Label' }
          }.new

          DataCycleCore::Thing.stub(:new, template) do
            DataCycleCore::ClassificationAlias.stub(:for_tree, ca_relation) do
              value = subject.to_additional_information(content:, virtual_parameters: ['description_field'], virtual_definition: { 'template_name' => 'Zusatzinformation' })

              assert_equal([template], value)
            end
          end
        end

        test 'to_additional_information returns nil when the template is missing' do
          template = Class.new { def template_missing? = true }.new

          DataCycleCore::Thing.stub(:new, template) do
            assert_nil(subject.to_additional_information(content: struct_double(id: 'c'), virtual_parameters: ['x'], virtual_definition: { 'template_name' => 'Missing' }))
          end
        end

        test 'odta_tourenstatus_as_trail_closed detects a closed external key' do
          relation = Class.new {
            def for_tree(_tree) = self
            def first = Struct.new(:external_key).new('tour_closed')
          }.new
          content = struct_double(classification_aliases: relation)

          assert(subject.odta_tourenstatus_as_trail_closed(content:))
        end

        test 'slugify converts the first parameter value to a slug' do
          content = struct_double(name: 'My Title')

          assert_equal('my-title', subject.slugify(content:, virtual_parameters: ['name']))
        end
      end
    end
  end
end
