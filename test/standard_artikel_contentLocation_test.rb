require 'test_helper'

module DataCycleCore
  class StandardArtikelContentLocationTest < ActiveSupport::TestCase

    test "create a contentLocation" do
      # create a contentLocations
      place_template = DataCycleCore::Place.find_by(template: true, headline: "contentLocation", description: "Place")
      place_validation = place_template.metadata['validation']
      data_set_place_1 = DataCycleCore::Place.new
      data_set_place_1.metadata = { 'validation' => place_validation }
      data_set_place_1.save
      place_hash1 = {
        "name" => "Wien",
        "latitude" => 1,
        "longitude" => 2
      }
      data_set_place_1.set_data_hash(place_hash1)
      data_set_place_1.save
      place_id_1 = data_set_place_1.id
      expected_hash = data_set_place_1.get_data_hash
      assert_equal(place_hash1.merge({"id" => place_id_1}), expected_hash.compact)
    end

    test "insert embeddedObject within same table" do
      # create an author
      person_template = DataCycleCore::Person.find_by(template: true, headline: "Autor", description: "Person")
      person_validation = person_template.metadata['validation']
      data_set_person = DataCycleCore::Person.new
      data_set_person.metadata = { 'validation' => person_validation }
      data_set_person.save
      person_hash = {
        "given_name" => "Winston",
        "family_name" => "Churchill"
      }
      data_set_person.set_data_hash(person_hash)
      data_set_person.save
      person_id = data_set_person.id

      data_type_zitat_id = DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
          .where("classification_tree_labels.name = ?", "Inhaltstypen")
          .where("classification_aliases.name = ?", "Zitat").first.id

      # create a contentLocations
      place_template = DataCycleCore::Place.find_by(template: true, headline: "contentLocation", description: "Place")
      place_validation = place_template.metadata['validation']
      data_set_place_1 = DataCycleCore::Place.new
      data_set_place_1.metadata = { 'validation' => place_validation }
      data_set_place_1.save
      place_hash1 = {
        "name" => "Wien",
        "latitude" => 1,
        "longitude" => 2
      }
      data_set_place_1.set_data_hash(place_hash1)
      data_set_place_1.save
      place_id_1 = data_set_place_1.id

      data_set_place_2 = DataCycleCore::Place.new
      data_set_place_2.metadata = { 'validation' => place_validation }
      data_set_place_2.save
      place_hash2 = {
        "name" => "Villach",
        "latitude" => 10,
        "longitude" => 20
      }
      data_set_place_2.set_data_hash(place_hash2)
      data_set_place_2.save
      place_id_2 = data_set_place_2.id

      # create an Article
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Standard-Artikel", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_hash = {
        "headline" => "Dies ist ein Test!",
        "text" => "wtf is going on???",
        "quotation" => [{
          "text" => "However beautiful the strategy, you should occasionally look at the results.",
          "author" => [{
            "id" => person_id
          }],
          "data_type" => [data_type_zitat_id]
        }],
        "content_location" => [{
          "id" => place_id_1
          }]
      }
      error = data_set.set_data_hash(data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      parent_id = data_set.id

      expected_hash = {
        "kind" => [],
        "tags" => [],
        "author" => [],
        "text" => "wtf is going on???",
        "state" => [],
        "season" => [],
        "topics" => [],
        "markets" => [],
        "headline" => "Dies ist ein Test!",
        "quotation" => [{
          "id" => "",
          "text" => "However beautiful the strategy, you should occasionally look at the results.",
          "image" => nil,
          "author" => [{
            "id" => person_id,
            "job_title" => nil,
            "given_name" => "Winston",
            "family_name" => "Churchill"
          }],
          "creator" => nil,
          "isPartOf" => parent_id,
          "data_type" => [data_type_zitat_id],
          "date_created"=>nil,
          "date_modified"=>nil
        }],
        "output_channels"=>[],
        "content_location"=>[{
          "id" => place_id_1,
          "name" => "Wien",
          "latitude" => 1,
          "longitude" => 2,
          "external_source_id" => nil,
          "location" => nil
          }]
      }
      expected_hash["quotation"][0]["id"]=returned_data_hash["quotation"][0]["id"]
      assert_equal(0, error[:error].count)
      assert_equal(expected_hash, returned_data_hash.compact.except('id',"data_type",'validity_period'))

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(1, DataCycleCore::CreativeWorkPerson.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)
      assert_equal(1, DataCycleCore::CreativeWorkPlace.count)
      assert_equal(2, DataCycleCore::Place.where(template: false).count)

      # change contentLocation via new id

      # ap DataCycleCore::Place.find(place_id_1).get_data_hash
      # ap DataCycleCore::Place.find(place_id_2).get_data_hash


      returned_data_hash['content_location'] = [{"id" => place_id_2 }]
      error = data_set.set_data_hash(returned_data_hash)
      data_set.save
      updated_data_hash = data_set.get_data_hash
      expected_hash["content_location"] = [{
        "id" => place_id_2,
        "name" => "Villach",
        "latitude" => 10,
        "longitude" => 20,
        "external_source_id" => nil,
        "location" => nil
        }]
      assert_equal(0, error[:error].count)
      assert_equal(expected_hash, updated_data_hash.compact.except('id',"data_type",'validity_period'))


      # check consistency of data in DB
      assert_equal(2, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(1, DataCycleCore::CreativeWorkPerson.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)
      assert_equal(1, DataCycleCore::CreativeWorkPlace.count)
      assert_equal(2, DataCycleCore::Place.where(template: false).count)

    end


  end
end
