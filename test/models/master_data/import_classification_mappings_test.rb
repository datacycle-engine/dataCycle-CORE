# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ImportClassificationMappingsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @base_path = Rails.root.join('..', 'fixtures', 'classifications', 'base')
      @append_path = Rails.root.join('..', 'fixtures', 'classifications', 'append')
      @clear_path = Rails.root.join('..', 'fixtures', 'classifications', 'clear_mappings')

      @importer = DataCycleCore::MasterData::ImportClassifications
    end

    test 'import base classifications and mappings' do
      @importer.import_all(classification_paths: [@base_path])
      concepts = DataCycleCore::ClassificationAlias.includes(:classification_alias_path, :primary_classification).for_tree(['FirstTree', 'SecondTree']).to_h { |ca| [ca.full_path, { primary_id: ca.primary_classification.id, additional_ids: ca.additional_classifications.pluck(:id) }] }

      assert_equal concepts.values_at('SecondTree > Tag 1').pluck(:primary_id).to_set, concepts.dig('FirstTree > Tag 1', :additional_ids).to_set
      assert_equal concepts.values_at('SecondTree > Tag 2', 'SecondTree > Tag 3').pluck(:primary_id).to_set, concepts.dig('FirstTree > Tag 2', :additional_ids).to_set
    end

    test 'import append classifications and mappings' do
      @importer.import_all(classification_paths: [@base_path, @append_path])
      concepts = DataCycleCore::ClassificationAlias.includes(:classification_alias_path, :primary_classification).for_tree(['FirstTree', 'SecondTree']).to_h { |ca| [ca.full_path, { primary_id: ca.primary_classification.id, additional_ids: ca.additional_classifications.pluck(:id) }] }

      assert_equal concepts.values_at('SecondTree > Tag 1').pluck(:primary_id).to_set, concepts.dig('FirstTree > Tag 1', :additional_ids).to_set
      assert_equal concepts.values_at('SecondTree > Tag 2', 'SecondTree > Tag 3').pluck(:primary_id).to_set, concepts.dig('FirstTree > Tag 2', :additional_ids).to_set
      assert_equal concepts.values_at('SecondTree > Tag 3 > Tag 3.1').pluck(:primary_id).to_set, concepts.dig('FirstTree > Tag 3', :additional_ids).to_set
    end

    test 'import clear classifications and mappings' do
      @importer.import_all(classification_paths: [@base_path, @clear_path])
      concepts = DataCycleCore::ClassificationAlias.includes(:classification_alias_path, :primary_classification).for_tree(['FirstTree', 'SecondTree']).to_h { |ca| [ca.full_path, { primary_id: ca.primary_classification.id, additional_ids: ca.additional_classifications.pluck(:id) }] }

      assert_equal [].to_set, concepts.dig('FirstTree > Tag 1', :additional_ids).to_set
      assert_equal [].to_set, concepts.dig('FirstTree > Tag 2', :additional_ids).to_set
      assert_equal [].to_set, concepts.dig('FirstTree > Tag 3', :additional_ids).to_set
    end
  end
end
