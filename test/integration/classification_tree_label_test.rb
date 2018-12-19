# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ClassificationTreeLabelTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'list subclassifications and contents for classification_tree_labels' do
      tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Inhaltstypen')
      get classification_tree_label_path(tree_label), params: {}, headers: {
        referer: root_path
      }
      assert_response :success

      article_tree_id = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').with_name('Artikel').first.classification_tree.id

      get classification_tree_label_path(tree_label), xhr: true, params: {
        classification_tree_id: article_tree_id
      }, headers: {
        referer: root_path
      }
      assert_response :success
      assert response.body.include?(@content.name)
    end
  end
end
