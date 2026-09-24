# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ConceptSchemeTreeTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    before(:all) do
      DataCycleCore::Thing.delete_all
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
    end

    setup do
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'list subclassifications and contents for concept_schemes' do
      tree_label = DataCycleCore::ConceptScheme.find_by(name: 'Inhaltstypen')
      get root_path(mode: 'tree', ctl_id: tree_label.id, reset: true), params: {}, headers: {
        referer: root_path
      }

      assert_response :success
    end

    test 'find classifications with ids' do
      classification_tree = DataCycleCore::ConceptScheme.find_by(name: 'Inhaltstypen')

      ids = classification_tree.concepts.map(&:id)

      get find_classifications_path, params: { ids: }, headers: {
        referer: root_path
      }

      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
      json_data = response.parsed_body

      assert_equal ids.size, json_data.size
    end
  end
end
