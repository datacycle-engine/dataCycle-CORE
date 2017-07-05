require 'test_helper'

# load template, classifications for all tests
creative_work_yaml = Rails.root.join('..','setup_data','creative_works.yml')
DataCycleCore::MasterData::ImportTemplates.new.import(creative_work_yaml, DataCycleCore::CreativeWork)
creative_work_yaml = Rails.root.join('..','setup_data','creative_works_test.yml')
DataCycleCore::MasterData::ImportTemplates.new.import(creative_work_yaml, DataCycleCore::CreativeWork)
place_yaml = Rails.root.join('..','setup_data','places.yml')
DataCycleCore::MasterData::ImportTemplates.new.import(place_yaml, DataCycleCore::Place)
person_yaml = Rails.root.join('..','setup_data','persons.yml')
DataCycleCore::MasterData::ImportTemplates.new.import(person_yaml, DataCycleCore::Person)
classification_yaml = Rails.root.join('..','setup_data','classifications.yml')
DataCycleCore::MasterData::ImportClassifications.new.import(classification_yaml)

module DataCycleCore
  class EmbeddedTreeTest < ActiveSupport::TestCase

    test "CreativeWork exists" do
      data = DataCycleCore::CreativeWork.new
      assert_equal(data.class, DataCycleCore::CreativeWork)
    end

    test "insert embeddedObject within same table" do
      # create an author
      template = DataCycleCore::Person.where(template: true, headline: "Autor", description: "Person").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::Person.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      person_hash = {
        "givenName" => "Winston",
        "familyName" => "Churchill"
      }
      data_set.set_data_hash(person_hash)
      data_set.save
      person_id = data_set.id

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
          }]
        }]
      }
      error = data_set.set_data_hash(data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      parent_id = data_set.id

      expected_hash = {
        "kind" => [],
        "tags" => [],
        "text" => "wtf is going on???",
        "state" => [],
        "season" => [],
        "topics" => [],
        "markets" => [],
        "headline" => "Dies ist ein Test!",
        "data_type" => [],
        "quotation" => [{
          "id" => "",
          "text" => "However beautiful the strategy, you should occasionally look at the results.",
          "image" => nil,
          "author" => [{
            "id" => person_id,
            "jobTitle" => nil,
            "givenName" => "Winston",
            "familyName" => "Churchill"
          }],
          "isPartOf" => parent_id
        }]
      }
      expected_hash["quotation"][0]["id"]=returned_data_hash["quotation"][0]["id"]
      assert_equal(0, error[:error].count)
      assert_equal(expected_hash, returned_data_hash.compact)

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(1, DataCycleCore::CreativeWorkPerson.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)
    end

    test 'insert quotation, then delete quotation' do
      # quotation is attached with "delete: true" --> should be deleted
      # author within quotation is without delete  --> only link should be deleted

      # create an author
      template = DataCycleCore::Person.where(template: true, headline: "Autor", description: "Person").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::Person.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      person_hash = {
        "givenName" => "Winston",
        "familyName" => "Churchill"
      }
      data_set.set_data_hash(person_hash)
      data_set.save
      person_id = data_set.id

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
          }]
        }]
      }
      error = data_set.set_data_hash(data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      parent_id = data_set.id

      expected_hash = {
        "kind" => [],
        "tags" => [],
        "text" => "wtf is going on???",
        "state" => [],
        "season" => [],
        "topics" => [],
        "markets" => [],
        "headline" => "Dies ist ein Test!",
        "data_type" => [],
        "quotation" => [{
          "id" => "",
          "text" => "However beautiful the strategy, you should occasionally look at the results.",
          "image" => nil,
          "author" => [{
            "id" => person_id,
            "jobTitle" => nil,
            "givenName" => "Winston",
            "familyName" => "Churchill"
          }],
          "isPartOf" => parent_id
        }]
      }
      expected_hash["quotation"][0]["id"]=returned_data_hash["quotation"][0]["id"]
      assert_equal(0, error[:error].count)
      assert_equal(expected_hash, returned_data_hash.compact)

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(1, DataCycleCore::CreativeWorkPerson.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)

      # delete quotation
      data_hash['quotation'] = []
      error = data_set.set_data_hash(data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      expected_hash['quotation'] = []

      assert_equal(0, error[:error].count)
      assert_equal(expected_hash, returned_data_hash.compact)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(0, DataCycleCore::CreativeWorkPerson.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)
    end

    test 'insert quotations, then delete quotations' do
      # quotation is attached with "delete: true" --> should be deleted
      # author within quotation is without delete  --> only link should be deleted

      # create an author
      template = DataCycleCore::Person.where(template: true, headline: "Autor", description: "Person").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::Person.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      person_hash = {
        "givenName" => "Winston",
        "familyName" => "Churchill"
      }
      data_set.set_data_hash(person_hash)
      data_set.save
      person_id = data_set.id

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
          }]
        },{
          "text" => "Men occasionally stumble over the truth, but most of them pick themselves up and hurry off as if nothing ever happened.",
          "author" => [{
            "id" => person_id
          }]
        }]
    }
      error = data_set.set_data_hash(data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      parent_id = data_set.id

      expected_hash = {
        "kind" => [],
        "tags" => [],
        "text" => "wtf is going on???",
        "state" => [],
        "season" => [],
        "topics" => [],
        "markets" => [],
        "headline" => "Dies ist ein Test!",
        "data_type" => [],
        "quotation" => [{
          "text" => "However beautiful the strategy, you should occasionally look at the results.",
          "image" => nil,
          "author" => [{
            "id" => person_id,
            "jobTitle" => nil,
            "givenName" => "Winston",
            "familyName" => "Churchill"
          }],
          "isPartOf" => parent_id
        },{
          "text" => "Men occasionally stumble over the truth, but most of them pick themselves up and hurry off as if nothing ever happened.",
          "image" => nil,
          "author" => [{
            "id" => person_id,
            "jobTitle" => nil,
            "givenName" => "Winston",
            "familyName" => "Churchill"
          }],
          "isPartOf" => parent_id
        }]
      }

      assert_equal(0, error[:error].count)
      assert_equal(expected_hash.except("quotation"), returned_data_hash.compact.except("quotation"))
      assert_equal(expected_hash["quotation"].count, returned_data_hash["quotation"].count)

      # check consistency of data in DB
      assert_equal(3, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(2, DataCycleCore::CreativeWorkPerson.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)

      # delete quotation
      data_hash['quotation'] = []
      error = data_set.set_data_hash(data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      expected_hash['quotation'] = []

      assert_equal(0, error[:error].count)
      assert_equal(expected_hash, returned_data_hash.compact)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(0, DataCycleCore::CreativeWorkPerson.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)
    end

    test "insert embeddedObject within same table then add another quotation" do
      # create an author
      template = DataCycleCore::Person.where(template: true, headline: "Autor", description: "Person").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::Person.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      person_hash = {
        "givenName" => "Winston",
        "familyName" => "Churchill"
      }
      data_set.set_data_hash(person_hash)
      data_set.save
      person_id = data_set.id

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
          }]
        }]
      }
      error = data_set.set_data_hash(data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      parent_id = data_set.id
      quotation_id = returned_data_hash["quotation"][0]["id"]

      expected_hash = {
        "kind" => [],
        "tags" => [],
        "text" => "wtf is going on???",
        "state" => [],
        "season" => [],
        "topics" => [],
        "markets" => [],
        "headline" => "Dies ist ein Test!",
        "data_type" => [],
        "quotation" => [{
          "id" => "",
          "text" => "However beautiful the strategy, you should occasionally look at the results.",
          "image" => nil,
          "author" => [{
            "id" => person_id,
            "jobTitle" => nil,
            "givenName" => "Winston",
            "familyName" => "Churchill"
          }],
          "isPartOf" => parent_id
        }]
      }
      expected_hash["quotation"][0]["id"] = returned_data_hash["quotation"][0]["id"]
      assert_equal(0, error[:error].count)
      assert_equal(expected_hash, returned_data_hash.compact)

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(1, DataCycleCore::CreativeWorkPerson.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)

      data_hash["quotation"][0]["id"] = quotation_id
      data_hash["quotation"].push({
        "text" => "Men occasionally stumble over the truth, but most of them pick themselves up and hurry off as if nothing ever happened.",
        "author" => [{
          "id" => person_id
        }]
      })
      error = data_set.set_data_hash(data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      parent_id = data_set.id

      assert_equal(0, error[:error].count)
      assert_equal(expected_hash.except("quotation"), returned_data_hash.compact.except("quotation"))
      assert_equal(2 , returned_data_hash["quotation"].count)

      # check consistency of data in DB
      assert_equal(3, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(2, DataCycleCore::CreativeWorkPerson.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)
    end

  end
end
