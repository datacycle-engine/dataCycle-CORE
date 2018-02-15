require 'test_helper'

module DataCycleCore
  class StandardArtikelContentLocationTest < ActiveSupport::TestCase
    test 'create a contentLocation' do
      # create a contentLocations
      place_template = DataCycleCore::Place.find_by(template: true, template_name: 'contentLocation')
      data_set_place1 = DataCycleCore::Place.new
      data_set_place1.schema = place_template.schema
      data_set_place1.template_name = place_template.template_name
      data_set_place1.save
      place_hash1 = {
        'name' => 'Wien',
        'latitude' => 1,
        'longitude' => 2
      }
      data_set_place1.set_data_hash(data_hash: place_hash1)
      data_set_place1.save
      place_id1 = data_set_place1.id
      expected_hash = data_set_place1.get_data_hash
      assert_equal(place_hash1.merge({ 'id' => place_id1 }), expected_hash.compact)
    end

    test 'insert embeddedObject within same table' do
      count_person = DataCycleCore::Person.count
      count_place = DataCycleCore::Place.count
      count_cw = DataCycleCore::CreativeWork.count

      # create an author
      person_template = DataCycleCore::Person.find_by(template: true, template_name: 'Autor')
      data_set_person = DataCycleCore::Person.new
      data_set_person.schema = person_template.schema
      data_set_person.template_name = person_template.template_name
      data_set_person.save
      person_hash = {
        'given_name' => 'Winston',
        'family_name' => 'Churchill'
      }
      data_set_person.set_data_hash(data_hash: person_hash, prevent_history: true)
      data_set_person.save
      person_id = data_set_person.id

      data_type_zitat_id = DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
        .where('classification_tree_labels.name = ?', 'Inhaltstypen')
        .where('classification_aliases.name = ?', 'Zitat').first.id

      # create a contentLocations
      place_template = DataCycleCore::Place.find_by(template: true, template_name: 'contentLocation')
      data_set_place1 = DataCycleCore::Place.new
      data_set_place1.schema = place_template.schema
      data_set_place1.template_name = place_template.template_name
      data_set_place1.save
      place_hash1 = {
        'name' => 'Wien',
        'latitude' => 1,
        'longitude' => 2
      }
      data_set_place1.set_data_hash(data_hash: place_hash1, prevent_history: true)
      data_set_place1.save
      place_id1 = data_set_place1.id

      data_set_place2 = DataCycleCore::Place.new
      data_set_place2.schema = place_template.schema
      data_set_place2.template_name = place_template.template_name
      data_set_place2.save
      place_hash2 = {
        'name' => 'Villach',
        'latitude' => 10,
        'longitude' => 20
      }
      data_set_place2.set_data_hash(data_hash: place_hash2, prevent_history: true)
      data_set_place2.save
      place_id2 = data_set_place2.id

      # create an Article
      template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Artikel')
      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      data_hash = {
        'headline' => 'Dies ist ein Test!',
        'text' => 'wtf is going on???',
        'quotation' => [{
          'text' => 'However beautiful the strategy, you should occasionally look at the results.',
          'author' => [{
            'id' => person_id
          }],
          'data_type' => [data_type_zitat_id]
        }],
        'content_location' => [{
          'id' => place_id1
        }]
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      parent_id = data_set.id

      expected_hash = {
        'kind' => [],
        'tags' => [],
        'permitted_creator' => [],
        'text' => 'wtf is going on???',
        'state' => [],
        'season' => [],
        'topics' => [],
        'markets' => [],
        'image' => [],
        'video' => [],
        'headline' => 'Dies ist ein Test!',
        'quotation' => [{
          'id' => '',
          'text' => 'However beautiful the strategy, you should occasionally look at the results.',
          'image' => [],
          'author' => [{
            'id' => person_id,
            'job_title' => nil,
            'given_name' => 'Winston',
            'family_name' => 'Churchill'
          }],
          'creator' => nil,
          'is_part_of' => parent_id,
          'data_type' => [data_type_zitat_id],
          'date_created' => nil,
          'date_modified' => nil
        }],
        'output_channels' => [],
        'content_location' => [{
          'id' => place_id1,
          'name' => 'Wien',
          'latitude' => 1.0,
          'longitude' => 2.0,
          'external_source_id' => nil,
          'location' => nil
        }]
      }
      expected_hash['quotation'][0]['id'] = returned_data_hash['quotation'][0]['id']
      assert_equal(0, error[:error].count)
      assert_equal(expected_hash, returned_data_hash.compact.except('id', 'data_type', 'validity_period', 'data_pool'))

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::CreativeWork.count - count_cw)
      assert_equal(3, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Person.count - count_person)
      assert_equal(2, DataCycleCore::Place.count - count_place)

      assert_equal(['DataCycleCore::CreativeWork'], DataCycleCore::ContentContent.all.pluck(:content_a_type).uniq)
      assert_equal(['DataCycleCore::CreativeWork', 'DataCycleCore::Place', 'DataCycleCore::Person'].sort, DataCycleCore::ContentContent.all.pluck(:content_b_type).uniq.sort)
      assert_equal(['author', 'content_location', 'quotation'], DataCycleCore::ContentContent.all.pluck(:relation_a).uniq.sort)
      assert_equal([''], DataCycleCore::ContentContent.all.pluck(:relation_b).uniq)

      returned_data_hash['content_location'] = [{ 'id' => place_id2 }]
      error = data_set.set_data_hash(data_hash: returned_data_hash)
      data_set.save
      updated_data_hash = data_set.get_data_hash
      expected_hash['content_location'] = [{
        'id' => place_id2,
        'name' => 'Villach',
        'latitude' => 10,
        'longitude' => 20,
        'external_source_id' => nil,
        'location' => nil
      }]
      assert_equal(0, error[:error].count)
      assert_equal(expected_hash, updated_data_hash.compact.except('id', 'data_type', 'validity_period', 'data_pool'))

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::CreativeWork.count - count_cw)
      assert_equal(3, DataCycleCore::ContentContent.count)
      assert_equal(3, DataCycleCore::ClassificationContent.count)
      assert_equal(1, DataCycleCore::Person.count - count_person)
      assert_equal(2, DataCycleCore::Place.count - count_place)
      assert_equal(3, DataCycleCore::CreativeWork::History.count)
      assert_equal(3, DataCycleCore::ContentContent::History.count)
      assert_equal(3, DataCycleCore::ClassificationContent::History.count)
      assert_equal(1, DataCycleCore::Person::History.count)
      assert_equal(1, DataCycleCore::Place::History.count)

      # update the whole data_set to see if it is properly moved to history
      new_hash = data_set.get_data_hash
      new_hash['headline'] = 'updated Test'
      error = data_set.set_data_hash(data_hash: new_hash)

      assert_equal(2, DataCycleCore::CreativeWork.count - count_cw)
      assert_equal(3, DataCycleCore::ContentContent.count)
      assert_equal(3, DataCycleCore::ClassificationContent.count)
      assert_equal(1, DataCycleCore::Person.count - count_person)
      assert_equal(2, DataCycleCore::Place.count - count_place)
      assert_equal(5, DataCycleCore::CreativeWork::History.count)
      assert_equal(6, DataCycleCore::ContentContent::History.count)
      assert_equal(6, DataCycleCore::ClassificationContent::History.count)
      assert_equal(2, DataCycleCore::Person::History.count)
      assert_equal(2, DataCycleCore::Place::History.count)

      # delete data_set
      data_set.destroy_content
      data_set.destroy

      # delete history
      data_set.histories.each do |item|
        item.destroy_content
        item.destroy
      end

      assert_equal(0, DataCycleCore::CreativeWork.count - count_cw)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::ClassificationContent.count)
      assert_equal(1, DataCycleCore::Person.count - count_person)
      assert_equal(2, DataCycleCore::Place.count - count_place)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)
      assert_equal(0, DataCycleCore::ClassificationContent::History.count)
      assert_equal(0, DataCycleCore::Person::History.count)
      assert_equal(0, DataCycleCore::Place::History.count)
    end
  end
end
