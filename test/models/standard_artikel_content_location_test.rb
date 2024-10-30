# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class StandardArtikelContentLocationTest < ActiveSupport::TestCase
    test 'create a Örtlichkeit' do
      data_set_place1 = DataCycleCore::Thing.new(template_name: 'Örtlichkeit')
      data_set_place1.save
      place_hash1 = {
        'name' => 'Wien',
        'latitude' => 1,
        'longitude' => 2,
        'tags' => [],
        'image' => [],
        'overlay' => [],
        'primary_image' => [],
        'output_channel' => [],
        'marketing_groups' => [],
        'external_status' => [],
        'feratel_facilities_accommodations' => [],
        'feratel_facilities_additional_services' => [],
        'external_content_score' => []
      }
      data_set_place1.set_data_hash(data_hash: place_hash1)
      data_set_place1.save
      expected_hash = data_set_place1.get_data_hash
      assert_equal(place_hash1, expected_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('place')).except('opening_hours_specification', 'opening_hours', 'potential_action', 'opening_hours_description'))
    end

    # TODO: move to generic embedded test
    # test 'insert embeddedObject within same table' do
    #   count_thing = DataCycleCore::Thing.count
    #
    #   # create an author
    #   data_set_person = DataCycleCore::TestPreparations.data_set_object('Person')
    #   data_set_person.save!
    #   person_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('things', 'winston')
    #   data_set_person.set_data_hash(data_hash: person_hash, prevent_history: true)
    #   person_id = data_set_person.id
    #
    #   data_type_zitat_id = DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
    #     .where('classification_tree_labels.name = ?', 'Inhaltstypen')
    #     .where('classification_aliases.name = ?', 'Zitat').first.id
    #
    #   # create a Örtlichkeit
    #   data_set_place1 = DataCycleCore::TestPreparations.data_set_object('Örtlichkeit')
    #   data_set_place1.save!
    #   place_hash1 = DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'place1')
    #   data_set_place1.set_data_hash(data_hash: place_hash1, prevent_history: true)
    #   place_id1 = data_set_place1.id
    #
    #   data_set_place2 = DataCycleCore::TestPreparations.data_set_object('Örtlichkeit')
    #   data_set_place2.save!
    #   place_hash2 = DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'place2')
    #   data_set_place2.set_data_hash(data_hash: place_hash2, prevent_history: true)
    #   place_id2 = data_set_place2.id
    #
    #   # create an Article
    #   data_set = DataCycleCore::TestPreparations.data_set_object('Artikel')
    #   data_set.save!
    #   data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'artikel').merge(
    #     'quotation' => [
    #       {
    #         'text' => 'However beautiful the strategy, you should occasionally look at the results.',
    #         'author' => [person_id],
    #         'data_type' => [data_type_zitat_id]
    #       }
    #     ],
    #     'content_location' => [place_id1]
    #   )
    #
    #   error = data_set.set_data_hash(data_hash: data_hash)
    #   data_set.save
    #   returned_data_hash = data_set.get_data_hash
    #
    #   expected_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'artikel').merge(
    #     'quotation' => [{
    #       'text' => 'However beautiful the strategy, you should occasionally look at the results.',
    #       'author' => [person_id]
    #     }],
    #     'content_location' => [place_id1]
    #   )
    #   assert_equal(0, error[:error].count)
    #   assert_equal(expected_hash.except('quotation', 'content_location'), returned_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
    #   assert_equal([place_id1], returned_data_hash['content_location'].pluck(:id))
    #   assert_equal(expected_hash['quotation'].first.except('author'), returned_data_hash['quotation'].first.except('author', *DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
    #   assert_equal([person_id], returned_data_hash['quotation'].first['author'].pluck(:id))
    #
    #   # check consistency of data in DB
    #   assert_equal(5, DataCycleCore::Thing.count - count_thing)
    #   assert_equal(3, DataCycleCore::ContentContent.count)
    #   assert_equal(['author', 'content_location', 'quotation'], DataCycleCore::ContentContent.all.pluck(:relation_a).uniq.sort)
    #
    #   returned_data_hash['content_location'] = [place_id2]
    #   error = data_set.set_data_hash(data_hash: returned_data_hash)
    #   data_set.save
    #   updated_data_hash = data_set.get_data_hash
    #
    #   assert_equal(0, error[:error].count)
    #   assert_equal(expected_hash.except('quotation', 'content_location'), updated_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
    #   assert_equal([place_id2], updated_data_hash['content_location'].pluck(:id))
    #   assert_equal(expected_hash['quotation'].first.except('author'), updated_data_hash['quotation'].first.except('author', *DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
    #   assert_equal([person_id], updated_data_hash['quotation'].first['author'].pluck(:id))
    #
    #   # check consistency of data in DB
    #   assert_equal(5, DataCycleCore::Thing.count - count_thing)
    #   assert_equal(3, DataCycleCore::ContentContent.count)
    #   assert_equal(7, DataCycleCore::ClassificationContent.count)
    #   assert_equal(3, DataCycleCore::Thing::History.count)
    #   assert_equal(3, DataCycleCore::ContentContent::History.count)
    #   assert_equal(4, DataCycleCore::ClassificationContent::History.count)
    #
    #   # update the whole data_set to see if it is properly moved to history
    #   new_hash = data_set.get_data_hash
    #   new_hash['name'] = 'updated Test'
    #   data_set.set_data_hash(data_hash: new_hash)
    #
    #   assert_equal(5, DataCycleCore::Thing.count - count_thing)
    #   assert_equal(3, DataCycleCore::ContentContent.count)
    #   assert_equal(7, DataCycleCore::ClassificationContent.count)
    #   assert_equal(5, DataCycleCore::Thing::History.count)
    #   assert_equal(6, DataCycleCore::ContentContent::History.count)
    #   assert_equal(8, DataCycleCore::ClassificationContent::History.count)
    #
    #   data_set.destroy_content
    #   data_set.histories.each(&:destroy_content)
    #
    #   assert_equal(3, DataCycleCore::Thing.count - count_thing)
    #   assert_equal(0, DataCycleCore::ContentContent.count)
    #   assert_equal(3, DataCycleCore::ClassificationContent.count)
    #   assert_equal(0, DataCycleCore::Thing::History.count)
    #   assert_equal(0, DataCycleCore::ContentContent::History.count)
    #   assert_equal(0, DataCycleCore::ClassificationContent::History.count)
    # end
  end
end
