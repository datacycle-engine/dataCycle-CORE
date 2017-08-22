require 'test_helper'

module DataCycleCore
  class SingleTest < ActiveSupport::TestCase

    test "faulty test" do
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

      value_hash, release_hash = data_set.extract_release(data_hash)
      assert_equal(expected_value_hash, value_hash)
      assert_equal(expected_release_hash, release_hash)

      processed_data_hash = data_set.merge_release(value_hash, release_hash)
      assert_equal(data_hash, processed_data_hash)
    end

  end
end
