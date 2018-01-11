require 'test_helper'

module DataCycleCore
  class ReleasableTest < ActiveSupport::TestCase
    test "CreativeWork data-type ReleaseTest releasable case" do
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
      expected_value_hash = {
        "headline" => "Dies ist ein Test!",
        "description" => "description",
        "description2" => "description2"
      }
      expected_release_hash = {
        "description" => {
          "release_id" => release_id,
          "release_comment" => "noch nicht fertig"
        }
      }
      value_hash, release_hash = data_set.extract_release(data_hash, true)
      assert_equal(expected_value_hash, value_hash)
      assert_equal(expected_release_hash, release_hash)

      processed_data_hash = data_set.merge_release(value_hash, release_hash)
      assert_equal(data_hash, processed_data_hash)
    end

    test "extract release from embeddedObjects" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "ReleaseTest", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save

      data_hash = {
        "image"=>{
          "value"=>["43aa35f4-0c6b-4648-a7da-c403e6450640", "76de5bef-3030-4315-a7f7-90951037a5c4", "46d4a2ac-3ae2-4c96-9ff8-b847911d3896"],
          "release_id"=>"40dc12d1-de50-4c58-abfb-c442eb134909",
          "release_comment"=>"sadfsadfasdf"
        },
        "headline"=>"Release Artikel 9",
        "quotation"=>[
          {
            "text"=>"<p>sdfaasdfasdf</p>",
            "image"=>{
              "value"=>["4fb7eb58-bdf9-402b-be29-1b822513a3fa"],
              "release_id"=>"2dd129f2-b913-4fb0-a659-b39abd8afeaa",
              "release_comment"=>""
            },
            "author"=>[]
          }
        ],
        "description"=>{
          "value"=>"",
          "release_id"=>"e2eb3206-0ab0-4842-9cb1-0c028a27d2d2",
          "release_comment"=>"hahaha"
        }
      }
      expected_value_hash = {
        "image"=> ["43aa35f4-0c6b-4648-a7da-c403e6450640", "76de5bef-3030-4315-a7f7-90951037a5c4", "46d4a2ac-3ae2-4c96-9ff8-b847911d3896"],
        "headline"=>"Release Artikel 9",
        "quotation"=>[
          {
            "text"=>"<p>sdfaasdfasdf</p>",
            "image"=>["4fb7eb58-bdf9-402b-be29-1b822513a3fa"],
            "author"=>[]
          }
        ],
        "description" => ""
      }
      expected_release_hash = {
        "image"=>{
          "release_id"=>"40dc12d1-de50-4c58-abfb-c442eb134909",
          "release_comment"=>"sadfsadfasdf"
        },
        "quotation"=>[
          {
            "image"=>{
              "release_id"=>"2dd129f2-b913-4fb0-a659-b39abd8afeaa",
              "release_comment"=>""
            }
          }
        ],
        "description"=>{
          "release_id"=>"e2eb3206-0ab0-4842-9cb1-0c028a27d2d2",
          "release_comment"=>"hahaha"
        }
      }
      value_hash, release_hash = data_set.extract_release(data_hash, true)
      assert_equal(expected_value_hash, value_hash)
      assert_equal(expected_release_hash, release_hash)

      processed_data_hash = data_set.merge_release(value_hash, release_hash)
      assert_equal(data_hash, processed_data_hash)
    end

    test "extract release from embeddedData" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "ReleaseTest", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save

      data_hash = {
        "image"=>{
          "value"=>["43aa35f4-0c6b-4648-a7da-c403e6450640", "76de5bef-3030-4315-a7f7-90951037a5c4", "46d4a2ac-3ae2-4c96-9ff8-b847911d3896"],
          "release_id"=>"40dc12d1-de50-4c58-abfb-c442eb134909",
          "release_comment"=>"sadfsadfasdf"
        },
        "test_data" => {
          "test1" => {
            "value"=>"test1",
            "release_id"=>"e2eb3206-0ab0-4842-9cb1-0c028a27d2d2",
            "release_comment"=>"hahaha"
          },
          "test2" => {
            "value"=>"test2",
            "release_id"=>"e2eb3206-0ab0-4842-9cb1-0c028a27d2d2",
            "release_comment"=>"hahaha"
          }
        },
        "description"=>{
          "value"=>"",
          "release_id"=>"e2eb3206-0ab0-4842-9cb1-0c028a27d2d2",
          "release_comment"=>"hahaha"
        }
      }
      expected_value_hash = {
        "image"=> ["43aa35f4-0c6b-4648-a7da-c403e6450640", "76de5bef-3030-4315-a7f7-90951037a5c4", "46d4a2ac-3ae2-4c96-9ff8-b847911d3896"],
        "test_data" => {
          "test1" => "test1",
          "test2" => "test2"
        },
        "description" => ""
      }
      expected_release_hash = {
        "image"=>{
          "release_id"=>"40dc12d1-de50-4c58-abfb-c442eb134909",
          "release_comment"=>"sadfsadfasdf"
        },
        "test_data" => {
          "test1" => {
            "release_id"=>"e2eb3206-0ab0-4842-9cb1-0c028a27d2d2",
            "release_comment"=>"hahaha"
          },
          "test2" => {
            "release_id"=>"e2eb3206-0ab0-4842-9cb1-0c028a27d2d2",
            "release_comment"=>"hahaha"
          }
        },
        "description"=>{
          "release_id"=>"e2eb3206-0ab0-4842-9cb1-0c028a27d2d2",
          "release_comment"=>"hahaha"
        }
      }

      value_hash, release_hash = data_set.extract_release(data_hash, true)
      assert_equal(expected_value_hash, value_hash)
      assert_equal(expected_release_hash, release_hash)

      processed_data_hash = data_set.merge_release(value_hash, release_hash)
      assert_equal(data_hash, processed_data_hash)
    end

    test "merge release data to data_hash" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "ReleaseTest", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save

      data_hash = {
        "kind" => [],
        "name" => "",
        "tags" => [],
        "text" => "",
        "image" => ["108bbf5f-08b0-4c10-a7cc-6094750fd317", "76de5bef-3030-4315-a7f7-90951037a5c4", "43aa35f4-0c6b-4648-a7da-c403e6450640"],
        "state" => [],
        "same_as" => "",
        "season" => [],
        "topics" => [],
        "markets" => [],
        "headline" => "Release Artikel 15",
        "keywords" => "", "meta_title" => "", "quotation" => [{
          "text" => "<p>sdfasf asdf adfasdf</p>",
          "image" => ["4fb7eb58-bdf9-402b-be29-1b822513a3fa"],
          "author" => []
        }],
        "description" => "",
        "output_channels" => [],
        "validity_period" => {
          "valid_from" => "",
          "valid_until" => ""
        },
        "content_location" => [],
        "meta_description" => "",
        "alternative_headline" => ""
      }
      release_hash = {
        "image" => {
          "release_id" => "40dc12d1-de50-4c58-abfb-c442eb134909",
          "release_comment" => "normales bild kommentar"
        },
        "quotation" => [{
          "image" => {
            "release_id" => "e2eb3206-0ab0-4842-9cb1-0c028a27d2d2",
            "release_comment" => "zitat bild kommentar"
          }
        }]
      }

      expected_hash = {
        "kind" => [],
        "name" => "",
        "tags" => [],
        "text" => "",
        "image" => {
          "value" => ["108bbf5f-08b0-4c10-a7cc-6094750fd317", "76de5bef-3030-4315-a7f7-90951037a5c4", "43aa35f4-0c6b-4648-a7da-c403e6450640"],
          "release_id" => "40dc12d1-de50-4c58-abfb-c442eb134909",
          "release_comment" => "normales bild kommentar"
        },
        "state" => [],
        "same_as" => "",
        "season" => [],
        "topics" => [],
        "markets" => [],
        "headline" => "Release Artikel 15",
        "keywords" => "",
        "meta_title" => "",
        "quotation" => [{
          "text" => "<p>sdfasf asdf adfasdf</p>",
          "image" => {
            "value" => ["4fb7eb58-bdf9-402b-be29-1b822513a3fa"],
            "release_id" => "e2eb3206-0ab0-4842-9cb1-0c028a27d2d2",
            "release_comment" => "zitat bild kommentar"
          },
          "author" => []
        }],
        "description" => "",
        "output_channels" => [],
        "validity_period" => {
          "valid_from" => "",
          "valid_until" => ""
        },
        "content_location" => [],
        "meta_description" => "",
        "alternative_headline" => ""
      }

      assert_equal(expected_hash, data_set.merge_release(data_hash, release_hash))
    end
  end
end
