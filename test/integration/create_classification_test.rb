# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class CreateClassificationTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes

      sign_in(User.find_by(email: 'admin@datacycle.at'))
    end

    test 'all classification trees are displayed' do
      get classifications_path

      assert_select('li.classification_tree_label', count: ConceptScheme.visible('classification_administration').count)
    end

    test 'new classification tree is displayed correctly' do
      classification_tree = ConceptScheme.create(name: 'CLASSIFICATION TREE I', visibility: ['classification_administration'])

      get classifications_path

      assert_select("li##{classification_tree.id} .name", text: 'CLASSIFICATION TREE I')
    end

    test 'create new classification tree' do
      post classifications_path, xhr: true, params: {
        concept_scheme: {
          name: 'CLASSIFICATION TREE II',
          visibility: [
            'show',
            'edit'
          ]
        }
      }

      tree_label = ConceptScheme.find_by(name: 'CLASSIFICATION TREE II')

      assert tree_label
      assert_equal ['show', 'edit'], tree_label.visibility
    end
  end
end
