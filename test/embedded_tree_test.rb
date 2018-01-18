require 'test_helper'

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
        "given_name" => "Winston",
        "family_name" => "Churchill"
      }
      data_set.set_data_hash(data_hash: person_hash)
      data_set.save
      person_id = data_set.id

      data_type_zitat_id = DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
        .where("classification_tree_labels.name = ?", "Inhaltstypen")
        .where("classification_aliases.name = ?", "Zitat").first.id

      # create an Article
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Artikel", description: "CreativeWork").first
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
        }]
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      parent_id = data_set.id

      expected_hash = {
        "kind" => [],
        "tags" => [],
        "image" => [],
        "video" => [],
        "text" => "wtf is going on???",
        "state" => [],
        "season" => [],
        "topics" => [],
        "markets" => [],
        "headline" => "Dies ist ein Test!",
        "quotation" => [{
          "id" => "",
          "text" => "However beautiful the strategy, you should occasionally look at the results.",
          "image" => [],
          "author" => [{
            "id" => person_id,
            "job_title" => nil,
            "given_name" => "Winston",
            "family_name" => "Churchill"
          }],
          "creator" => nil,
          "is_part_of" => parent_id,
          "data_type" => [data_type_zitat_id],
          "date_created" => nil,
          "date_modified" => nil
        }],
        "output_channels" => [],
        "content_location" => [],
        "permitted_creator" => []
      }
      expected_hash["quotation"][0]["id"] = returned_data_hash["quotation"][0]["id"]
      assert_equal(0, error[:error].count)
      assert_equal(expected_hash, returned_data_hash.compact.except('id', 'data_type', 'data_pool'))

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(2, DataCycleCore::ContentContent.count)
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
        "given_name" => "Winston",
        "family_name" => "Churchill"
      }
      data_set.set_data_hash(data_hash: person_hash)
      data_set.save
      person_id = data_set.id

      data_type_zitat_id = DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
        .where("classification_tree_labels.name = ?", "Inhaltstypen")
        .where("classification_aliases.name = ?", "Zitat").first.id

      # create an Article
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Artikel", description: "CreativeWork").first
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
        }]
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      parent_id = data_set.id

      expected_hash = {
        "kind" => [],
        "tags" => [],
        "image" => [],
        "video" => [],
        "text" => "wtf is going on???",
        "state" => [],
        "season" => [],
        "topics" => [],
        "markets" => [],
        "headline" => "Dies ist ein Test!",
        "quotation" => [{
          "id" => "",
          "text" => "However beautiful the strategy, you should occasionally look at the results.",
          "image" => [],
          "author" => [{
            "id" => person_id,
            "job_title" => nil,
            "given_name" => "Winston",
            "family_name" => "Churchill"
          }],
          "creator" => nil,
          "is_part_of" => parent_id,
          "data_type" => [data_type_zitat_id],
          "date_created" => nil,
          "date_modified" => nil
        }],
        "output_channels" => [],
        "content_location" => [],
        "permitted_creator" => []
      }
      expected_hash["quotation"][0]["id"] = returned_data_hash["quotation"][0]["id"]
      assert_equal(0, error[:error].count)
      assert_equal(expected_hash, returned_data_hash.compact.except("id", "data_type", 'data_pool'))

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(2, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)
      assert_equal(3, DataCycleCore::ClassificationContent.count)

      # delete quotation
      data_hash['quotation'] = []
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      expected_hash['quotation'] = []

      assert_equal(0, error[:error].count)
      assert_equal(expected_hash, returned_data_hash.compact.except("id", "data_type", 'data_pool'))

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)
      assert_equal(2, DataCycleCore::ClassificationContent.count)
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
        "given_name" => "Winston",
        "family_name" => "Churchill"
      }
      data_set.set_data_hash(data_hash: person_hash)
      data_set.save
      person_id = data_set.id

      # create an Article
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Artikel", description: "CreativeWork").first
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
        }, {
          "text" => "Men occasionally stumble over the truth, but most of them pick themselves up and hurry off as if nothing ever happened.",
          "author" => [{
            "id" => person_id
          }]
        }]
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      parent_id = data_set.id

      expected_hash = {
        "kind" => [],
        "tags" => [],
        "image" => [],
        "video" => [],
        "text" => "wtf is going on???",
        "state" => [],
        "season" => [],
        "topics" => [],
        "markets" => [],
        "headline" => "Dies ist ein Test!",
        "output_channels" => [],
        "content_location" => [],
        "permitted_creator" => [],
        "quotation" => [{
          "text" => "However beautiful the strategy, you should occasionally look at the results.",
          "image" => [],
          "author" => [{
            "id" => person_id,
            "job_title" => nil,
            "given_name" => "Winston",
            "family_name" => "Churchill"
          }],
          "is_part_of" => parent_id
        }, {
          "text" => "Men occasionally stumble over the truth, but most of them pick themselves up and hurry off as if nothing ever happened.",
          "image" => nil,
          "author" => [{
            "id" => person_id,
            "job_title" => nil,
            "given_name" => "Winston",
            "family_name" => "Churchill"
          }],
          "is_part_of" => parent_id
        }]
      }

      assert_equal(0, error[:error].count)
      assert_equal(expected_hash.except("quotation", "data_type"), returned_data_hash.compact.except("quotation", "id", "data_type", 'data_pool'))
      assert_equal(expected_hash["quotation"].count, returned_data_hash["quotation"].count)

      # check consistency of data in DB
      assert_equal(3, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(4, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)

      # delete quotation
      data_hash['quotation'] = []
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      expected_hash['quotation'] = []
      assert_equal(0, error[:error].count)
      assert_equal(expected_hash, returned_data_hash.compact.except("id", "data_type", 'data_pool'))

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(0, DataCycleCore::ContentContent.count)
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
        "given_name" => "Winston",
        "family_name" => "Churchill"
      }
      data_set.set_data_hash(data_hash: person_hash)
      data_set.save
      person_id = data_set.id

      data_type_zitat_id = DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
        .where("classification_tree_labels.name = ?", "Inhaltstypen")
        .where("classification_aliases.name = ?", "Zitat").first.id

      # create an Article
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Artikel", description: "CreativeWork").first
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
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      parent_id = data_set.id
      quotation_id = returned_data_hash["quotation"][0]["id"]

      expected_hash = {
        "kind" => [],
        "tags" => [],
        "image" => [],
        "video" => [],
        "text" => "wtf is going on???",
        "state" => [],
        "season" => [],
        "topics" => [],
        "markets" => [],
        "headline" => "Dies ist ein Test!",
        "quotation" => [{
          "id" => "",
          "text" => "However beautiful the strategy, you should occasionally look at the results.",
          "image" => [],
          "creator" => nil,
          "author" => [{
            "id" => person_id,
            "job_title" => nil,
            "given_name" => "Winston",
            "family_name" => "Churchill"
          }],
          "is_part_of" => parent_id,
          "data_type" => [data_type_zitat_id],
          "date_created" => nil,
          "date_modified" => nil
        }],
        "output_channels" => [],
        "content_location" => [],
        'permitted_creator' => []
      }
      expected_hash["quotation"][0]["id"] = returned_data_hash["quotation"][0]["id"]
      assert_equal(0, error[:error].count)
      assert_equal(expected_hash, returned_data_hash.compact.except("id", "data_type", 'data_pool'))

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(2, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)

      data_hash["quotation"][0]["id"] = quotation_id
      data_hash["quotation"].push({
                                    "text" => "Men occasionally stumble over the truth, but most of them pick themselves up and hurry off as if nothing ever happened.",
                                    "author" => [{
                                      "id" => person_id
                                    }]
                                  })
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      parent_id = data_set.id

      assert_equal(0, error[:error].count)
      assert_equal(expected_hash.except("quotation"), returned_data_hash.compact.except("quotation", "id", "data_type", 'data_pool'))
      assert_equal(2, returned_data_hash["quotation"].count)

      # check consistency of data in DB
      assert_equal(3, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(4, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)
    end
  end
end
