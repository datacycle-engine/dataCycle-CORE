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

      assert_select('li.classification_tree_label', count: ClassificationTreeLabel.count)
    end

    test 'new classification tree is displayed correctly' do
      classification_tree = ClassificationTreeLabel.create(name: 'CLASSIFICATION TREE I')

      get classifications_path

      assert_select("li##{classification_tree.id} .name", text: 'CLASSIFICATION TREE I')
    end

    test 'create new classification tree' do
      post classifications_path, xhr: true, params: {
        classification_tree_label: {
          name: 'CLASSIFICATION TREE II',
          visibility: [
            'show',
            'edit'
          ]
        }
      }

      tree_label = ClassificationTreeLabel.find_by(name: 'CLASSIFICATION TREE II')
      assert tree_label
      assert_equal ['show', 'edit'], tree_label.visibility
    end
  end
end
