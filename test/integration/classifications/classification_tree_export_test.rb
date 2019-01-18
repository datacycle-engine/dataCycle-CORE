# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ClassificationTreeLabelTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes

      TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel 1' })
      TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel 2' })

      TestPreparations.create_content(template_name: 'Angebot', data_hash: { name: 'TestAngebot 1' })
      TestPreparations.create_content(template_name: 'Angebot', data_hash: { name: 'TestAngebot 2' })
      TestPreparations.create_content(template_name: 'Angebot', data_hash: { name: 'TestAngebot 3' })

      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'download full classification tree without content' do
      tree_label = ClassificationTreeLabel.find_by(name: 'Inhaltstypen')

      get download_classifications_path, params: { classification_tree_label_id: tree_label.id, format: 'csv' }

      assert_response :success

      csv = CSV.parse(body.encode('utf-8'))[1..-1] # skipping first line because of separator information for Microsoft Excel

      assert_equal csv[0][0], tree_label.name

      # testing on sub tree only
      sub_csv = extract_sub_tree(csv, [nil, 'Asset'])

      classification_alias = ClassificationAlias.for_tree(tree_label.name).with_name('Asset').first

      assert_equal classification_alias.sub_classification_alias.count, sub_csv.count - 1

      assert_includes sub_csv, [nil, 'Asset']
      classification_alias.sub_classification_alias.each do |sub_classification_alias|
        assert_includes sub_csv, [nil, nil, sub_classification_alias.name]
      end
    end

    test 'download full classification tree with contents' do
      tree_label = ClassificationTreeLabel.find_by(name: 'Inhaltstypen')

      get download_classifications_path,
          params: { classification_tree_label_id: tree_label.id, include_contents: true, format: 'csv' }

      assert_response :success

      csv = CSV.parse(body.encode('utf-8'))[1..-1] # skipping first line because of separator information for Microsoft Excel

      assert_equal csv[0][0], tree_label.name

      text_sub_csv = extract_sub_tree(csv, [nil, 'Text'])
      [1, 2].each do |i|
        assert_not_includes text_sub_csv, [nil, nil, 'Artikel', 'de', "TestArtikel #{i}"]
      end
      [1, 3].each do |i|
        assert_not_includes text_sub_csv, [nil, nil, 'Angebot', 'de', "TestAngebot #{i}"]
      end

      article_sub_csv = extract_sub_tree(csv, [nil, nil, 'Artikel'])
      [1, 2].each do |i|
        assert_includes article_sub_csv, [nil, nil, nil, 'Artikel', 'de', "TestArtikel #{i}"]
      end

      offer_sub_csv = extract_sub_tree(csv, [nil, nil, 'Angebot'])
      [1, 2, 3].each do |i|
        assert_includes offer_sub_csv, [nil, nil, nil, 'Angebot', 'de', "TestAngebot #{i}"]
      end
    end

    def extract_sub_tree(csv, classification_path)
      sub_tree_start_index = csv.index(classification_path)

      sub_tree_end_index = 1 + csv[sub_tree_start_index + 1, csv.count].index do |row|
        row[classification_path.take_while(&:nil?).count].present?
      end

      csv[sub_tree_start_index, sub_tree_end_index]
    end
  end
end
