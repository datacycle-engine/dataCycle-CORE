require 'test_helper'

module DataCycleCore
  class DataHashServiceTest < ActiveSupport::TestCase
    test "compare hashes with simple values (is equal)" do
      orig_hash = {
        "headline" => "my headline",
        "alternative_headline" => "my subheader test"
      }
      new_hash = {
        "headline" => "my headline",
        "alternative_headline" => "my subheader test"
      }
      is_dirty = DataCycleCore::DataHashService.data_hash_is_dirty?(new_hash, orig_hash)
      assert_equal(false, is_dirty)
    end

    test "compare hashes with simple values (is not equal)" do
      orig_hash = {
        "headline" => "my headline",
        "alternative_headline" => "my sub2header test"
      }
      new_hash = {
        "headline" => "my headline",
        "alternative_headline" => "another subheader"
      }
      is_dirty = DataCycleCore::DataHashService.data_hash_is_dirty?(new_hash, orig_hash)
      assert_equal(true, is_dirty)
    end

    test "compare hashes with empty values (is equal)" do
      orig_hash = {
        "headline" => "my headline",
        "alternative_headline" => "my subheader test",
        "empty_array" => [],
        "empty_string" => "",
        "empty_hash" => {},
      }
      new_hash = {
        "headline" => "my headline",
        "alternative_headline" => "my subheader test"
      }
      is_dirty = DataCycleCore::DataHashService.data_hash_is_dirty?(new_hash, orig_hash)
      assert_equal(false, is_dirty)
    end

    test "compare hashes with empty values and internal values (is equal)" do
      orig_hash = {
        "headline" => "my headline",
        "alternative_headline" => "my subheader test",
        "empty_array" => [],
        "empty_string" => "",
        "empty_hash" => {},
        "data_pool" => ["bdc1c0cb-b516-47e5-96e8-443bf7e9b82c"],
        "data_type" => ["36e31f95-eb11-4828-ba07-318148878f4d"]
      }
      new_hash = {
        "headline" => "my headline",
        "alternative_headline" => "my subheader test"
      }
      is_dirty = DataCycleCore::DataHashService.data_hash_is_dirty?(new_hash, orig_hash)
      assert_equal(false, is_dirty)
    end

    test "compare hashes with embedded objects incl. internal and empty properties (is equal)" do
      orig_hash = {
        "headline" => "my headline",
        "alternative_headline" => "my subheader test",
        "empty_array" => [],
        "empty_string" => "",
        "empty_hash" => {},
        "data_pool" => ["bdc1c0cb-b516-47e5-96e8-443bf7e9b82c"],
        "data_type" => ["36e31f95-eb11-4828-ba07-318148878f4d"],
        "question" => [{
          "id" => "b3b490c7-12a1-463a-8ec3-ba49c8245503",
          "text" => "<p>awefasdfasdf</p>",
          "image" => nil,
          "creator" => nil,
          "headline" => "asdf",
          "data_type" => ["719575c9-857a-4e34-bda8-ea1180e5feaa"],
          "date_created" => nil,
          "date_modified" => nil,
          "accepted_answer" => [{
            "id" => "05845d09-0e00-44c5-a93d-cbe98095cb27",
            "text" => "<p>fadsfddd</p>",
            "image" => ["0045d4d9-4cd7-4511-9935-01d386b36933"],
            "creator" => nil,
            "data_type" => ["e58589c2-4007-4d4f-969d-7a9249189afc"],
            "is_part_of" => nil,
            "date_created" => nil,
            "date_modified" => nil
          }],
          "suggested_answer" => [{
            "id" => "b1adcca1-5b2d-49be-8328-7805ae383dff",
            "text" => "<p>asdfasdf</p>",
            "image" => nil,
            "creator" => nil,
            "data_type" => ["e58589c2-4007-4d4f-969d-7a9249189afc"],
            "is_part_of" => nil,
            "date_created" => nil,
            "date_modified" => nil
          }]
        },
                       {
                         "id" => "a65426d9-5291-4bc7-b917-c297efb653f3",
                         "text" => "<p>asdf</p>",
                         "image" => nil,
                         "creator" => nil,
                         "headline" => "awefwefwef",
                         "data_type" => ["719575c9-857a-4e34-bda8-ea1180e5feaa"],
                         "date_created" => nil,
                         "date_modified" => nil,
                         "accepted_answer" => [],
                         "suggested_answer" => []
                       }],
      }
      new_hash = {
        "headline" => "my headline",
        "alternative_headline" => "my subheader test",
        "question" => [{
          "id" => "b3b490c7-12a1-463a-8ec3-ba49c8245503",
          "text" => "<p>awefasdfasdf</p>",
          "image" => nil,
          "headline" => "asdf",
          "data_type" => ["719575c9-857a-4e34-bda8-ea1180e5feaa"],
          "accepted_answer" => [{
            "id" => "05845d09-0e00-44c5-a93d-cbe98095cb27",
            "text" => "<p>fadsfddd</p>",
            "image" => ["0045d4d9-4cd7-4511-9935-01d386b36933"],
          }],
          "suggested_answer" => [{
            "id" => "b1adcca1-5b2d-49be-8328-7805ae383dff",
            "text" => "<p>asdfasdf</p>",
            "image" => nil,
          }]
        },
                       {
                         "id" => "a65426d9-5291-4bc7-b917-c297efb653f3",
                         "text" => "<p>asdf</p>",
                         "image" => nil,
                         "headline" => "awefwefwef",
                         "accepted_answer" => [],
                         "suggested_answer" => []
                       }],
      }
      is_dirty = DataCycleCore::DataHashService.data_hash_is_dirty?(new_hash, orig_hash)
      assert_equal(false, is_dirty)
    end

    test "compare hashes with embedded objects incl. internal and empty properties (is not equal)" do
      orig_hash = {
        "headline" => "my headline",
        "alternative_headline" => "my subheader test",
        "empty_array" => [],
        "empty_string" => "",
        "empty_hash" => {},
        "data_pool" => ["bdc1c0cb-b516-47e5-96e8-443bf7e9b82c"],
        "data_type" => ["36e31f95-eb11-4828-ba07-318148878f4d"],
        "question" => [{
          "id" => "b3b490c7-12a1-463a-8ec3-ba49c8245503",
          "text" => "<p>awefasdfasdf</p>",
          "image" => nil,
          "creator" => nil,
          "headline" => "asdf",
          "data_type" => ["719575c9-857a-4e34-bda8-ea1180e5feaa"],
          "date_created" => nil,
          "date_modified" => nil,
          "accepted_answer" => [{
            "id" => "05845d09-0e00-44c5-a93d-cbe98095cb27",
            "text" => "<p>fadsfddd</p>",
            "image" => ["0045d4d9-4cd7-4511-9935-01d386b36933"],
            "creator" => nil,
            "data_type" => ["e58589c2-4007-4d4f-969d-7a9249189afc"],
            "is_part_of" => nil,
            "date_created" => nil,
            "date_modified" => nil
          }],
          "suggested_answer" => [{
            "id" => "b1adcca1-5b2d-49be-8328-7805ae383dff",
            "text" => "<p>asdfasdf</p>",
            "image" => nil,
            "creator" => nil,
            "data_type" => ["e58589c2-4007-4d4f-969d-7a9249189afc"],
            "is_part_of" => nil,
            "date_created" => nil,
            "date_modified" => nil
          }]
        },
                       {
                         "id" => "a65426d9-5291-4bc7-b917-c297efb653f3",
                         "text" => "<p>asdf</p>",
                         "image" => nil,
                         "creator" => nil,
                         "headline" => "awefwefwef",
                         "data_type" => ["719575c9-857a-4e34-bda8-ea1180e5feaa"],
                         "date_created" => nil,
                         "date_modified" => nil,
                         "accepted_answer" => [],
                         "suggested_answer" => []
                       }],
      }
      new_hash = {
        "headline" => "my headline",
        "alternative_headline" => "my subheader test",
        "question" => [{
          "id" => "b3b490c7-12a1-463a-8ec3-ba49c8245503",
          "text" => "<p>awefasdfasdf</p>",
          "image" => nil,
          "headline" => "asdf",
          "data_type" => ["719575c9-857a-4e34-bda8-ea1180e5feaa"],
          "accepted_answer" => [{
            "id" => "05845d09-0e00-44c5-a93d-cbe98095cb27",
            "text" => "<p>fadsfddd 2</p>",
            "image" => ["0045d4d9-4cd7-4511-9935-01d386b36933"],
          }],
          "suggested_answer" => [{
            "id" => "b1adcca1-5b2d-49be-8328-7805ae383dff",
            "text" => "<p>asdfasdf</p>",
            "image" => nil,
          }]
        },
                       {
                         "id" => "a65426d9-5291-4bc7-b917-c297efb653f3",
                         "text" => "<p>asdf</p>",
                         "image" => nil,
                         "headline" => "awefwefwef",
                         "accepted_answer" => [],
                         "suggested_answer" => []
                       }],
      }
      is_dirty = DataCycleCore::DataHashService.data_hash_is_dirty?(new_hash, orig_hash)
      assert_equal(true, is_dirty)
    end
  end
end
