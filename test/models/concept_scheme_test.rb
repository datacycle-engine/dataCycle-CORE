# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ConceptSchemeTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @es_id = ExternalSystem.first.id
      @ctl = ClassificationTreeLabel.create(name: SecureRandom.hex(10), external_source_id: @es_id)
    end

    test 'concept_scheme gets created from classification_tree_label' do
      assert_equal @ctl.name, @ctl.concept_scheme.name
      assert_equal @ctl.external_source_id, @ctl.concept_scheme.external_system_id
    end

    test 'concept_scheme gets updated from classification_tree_label' do
      @ctl.update(name: SecureRandom.hex(10))

      assert_equal @ctl.name, @ctl.concept_scheme.name
    end

    test 'concept_scheme gets delete when classification_tree_label is soft deleted' do
      @ctl.destroy

      assert_raise(ActiveRecord::RecordNotFound) do
        ConceptScheme.find(@ctl.id)
      end
    end

    test 'concept_scheme gets delete when classification_tree_label is really deleted' do
      @ctl.destroy_fully!

      assert_raise(ActiveRecord::RecordNotFound) do
        ConceptScheme.find(@ctl.id)
      end
    end

    test 'create new concept_scheme' do
      concept_scheme1 = ConceptScheme.create(name: 'test', external_system_id: @es_id, internal: true, visibility: ['show'])

      assert concept_scheme1.is_a?(ConceptScheme)
      assert_equal 'test', concept_scheme1.name
      assert_equal @es_id, concept_scheme1.external_system_id
      assert concept_scheme1.internal
      assert_equal ['show'], concept_scheme1.visibility
      assert_equal ['trigger_webhooks'], concept_scheme1.change_behaviour
    end

    test 'create! new concept_scheme' do
      concept_scheme1 = ConceptScheme.create(name: 'test', external_system_id: @es_id, internal: true, visibility: ['show'])

      assert concept_scheme1.is_a?(ConceptScheme)
      assert_equal 'test', concept_scheme1.name
      assert_equal @es_id, concept_scheme1.external_system_id
      assert concept_scheme1.internal
      assert_equal ['show'], concept_scheme1.visibility
      assert_equal ['trigger_webhooks'], concept_scheme1.change_behaviour
    end

    test 'readonly?, visibility and the api / sync / select serializers' do
      scheme = ConceptScheme.create(name: 'cov', external_system_id: @es_id, internal: true, visibility: ['show'])

      assert_predicate scheme, :readonly?
      assert_equal :de, scheme.first_available_locale
      assert scheme.visible?('show')
      assert_not scheme.visible?('edit')
      assert_equal scheme.id, scheme.to_api_default_values['@id']
      assert_equal 'DataCycleCore::ConceptScheme', scheme.to_hash['class_type']
      assert_kind_of DataCycleCore::Filter::SelectOption, scheme.to_select_option
      assert_kind_of Hash, scheme.to_sync_data
      assert_kind_of ActiveRecord::Relation, scheme.stored_filters
    end

    test 'create and create! accept an array of attribute hashes' do
      assert_equal [], ConceptScheme.create([])
      assert_equal [], ConceptScheme.create!([])
    end

    test 'class-level select options and sync data map over all schemes' do
      assert_kind_of Array, ConceptScheme.to_select_options
      assert_kind_of Array, ConceptScheme.to_sync_data
    end
  end
end
