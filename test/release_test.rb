require 'test_helper'

module DataCycleCore
  class ReleaseTest < ActiveSupport::TestCase

    test "save CreativeWork data-type ReleaseTest" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "ReleaseTest", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_hash = {
        "headline" => "Dies ist ein Test!",
        "description" => "description",
        "description2" => "description2"
      }
      error = data_set.set_data_hash(data_hash)
      data_set.save
      assert_equal(data_hash, data_set.get_data_hash.compact)
    end

    test "save CreativeWork data-type ReleaseTest with status" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "ReleaseTest", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save

      release_id = DataCycleCore::Release.find_by(release_code: 10).id

      data_hash = {
        "headline" => "Dies ist ein Test!",
        "description" => {
          "value" => "description",
          "release_id" => release_id,
          "release_comment" => "noch nicht fertig"
        },
        "description2" => "description2"
      }
      error = data_set.set_data_hash(data_hash)
      data_set.save

      assert_equal(data_hash, data_set.get_data_hash)
      assert_equal(release_id, data_set.release_id)
    end

    test "save releasable embeddedObjects (Standard-Artikel/Zitat)" do
      template = DataCycleCore::CreativeWork.find_by(template: true, headline: "Standard-Artikel", description: "CreativeWork")
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save

      template_bild = DataCycleCore::CreativeWork.find_by(template: true, headline: "Bild", description: "ImageObject")

      bild1 = DataCycleCore::CreativeWork.new
      bild1.metadata = { 'validation' => template_bild.metadata['validation'] }
      bild1.save
      bild1.set_data_hash({"headline" => "Testbild1"})
      bild1.save

      bild2 = DataCycleCore::CreativeWork.new
      bild2.metadata = { 'validation' => template_bild.metadata['validation'] }
      bild2.save
      bild2.set_data_hash({"headline" => "Testbild2"})
      bild2.save

      data_hash = {
        "kind" => [],
        "tags" => [],
        "image" => {
          "value" => [bild1.id],
          "release_id" => DataCycleCore::Release.first.id,
          "release_comment" => "normales bild kommentar"
        },
        "state" => [],
        "season" => [],
        "topics" => [],
        "markets" => [],
        "headline" => "Release Artikel 15",
        "quotation" => [{
          "text" => "<p>sdfasf asdf adfasdf</p>",
          "image" => {
            "value" => [bild2.id],
            "release_id" => DataCycleCore::Release.second.id,
            "release_comment" => "zitat bild kommentar"
          },
          "author" => []
        }],
        "author" => [],
        "output_channels" => [],
        "content_location" => []
      }

      error = data_set.set_data_hash(data_hash)
      data_set.save

      returned_data_hash = data_set.get_data_hash
      assert_equal(data_hash.except('quotation'), returned_data_hash.compact.except('id','data_type','quotation'))
      assert_equal(data_hash['quotation'][0], returned_data_hash['quotation'][0].compact.except('id', 'data_type', 'is_part_of'))

      expected_release_main_object = {
        "image" => {
          "release_id" => DataCycleCore::Release.first.id,
          "release_comment" => "normales bild kommentar"
        }
      }
      assert_equal(expected_release_main_object, data_set.release)

      expected_release_quotation = {
        "image" => {
          "release_id" => DataCycleCore::Release.second.id,
          "release_comment" => "zitat bild kommentar"
        }
      }
      assert_equal(expected_release_quotation, DataCycleCore::CreativeWork.find(returned_data_hash['quotation'][0]['id']).release)

      expected_release_code = [DataCycleCore::Release.first.release_code, DataCycleCore::Release.second.release_code].max
      assert_equal(expected_release_code, data_set.release_status_code)
    end

  end
end
