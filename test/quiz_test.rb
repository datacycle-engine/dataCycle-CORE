require 'test_helper'

module DataCycleCore
  class QuizTest < ActiveSupport::TestCase

    test "CreativeWork exists" do
      data = DataCycleCore::CreativeWork.new
      assert_equal(data.class, DataCycleCore::CreativeWork)
    end

    test "generate a Quiz with questions, then delete all questions and answers" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Quiz", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_hash = {
        "headline" => "Dies ist ein Test Quiz!",
        "alternativeHeadline" => "ein lustiges Quiz für jeden Tag!",
        "question" => [
        {
          "headline" => "beliebtestes Handy-OS?",
          "suggestedAnswer" => [
            { "text" => "Android" },
            { "text" => "iOS" },
            { "text" => "Sailfish"},
            { "text" => "Ubuntu Phone"}
          ],
          "acceptedAnswer" => [
            { "text" => "Android"}
          ]
        },
        {
          "headline" => "bestes Desktop OS?",
          "suggestedAnswer" => [
            { "text" => "Linux"},
            { "text" => "BSD"},
            { "text" => "Windows"},
            { "text" => "sonstige"}
          ],
          "acceptedAnswer" => [
            { "text" => "Linux"}
          ]
        }
        ]
      }
      expected_hash_quiz = {
        "kind" => [],
        "tags" => [],
        "state" => [],
        "season" => [],
        "topics" => [],
        "markets" => [],
        "headline" => "Dies ist ein Test Quiz!",
        "outputChannels" => [],
        "alternativeHeadline" => "ein lustiges Quiz für jeden Tag!"
       }

      error = data_set.set_data_hash(data_hash)
      data_set.save

      puts "now get data"

      ap data_set.property_names
      ap data_set.embedded_property_names
      ap data_set.included_property_names
      ap data_set.question.map(&:to_h)

      returned_data_hash = data_set.get_data_hash

      puts "check data"

      assert_equal(0, error[:error].count)
      assert_equal(expected_hash_quiz, returned_data_hash.except("question","id","data_type").compact)
      assert_equal(2, returned_data_hash["question"].count)
      assert_equal(4, returned_data_hash["question"][0]["suggestedAnswer"].count)
      assert_equal(4, returned_data_hash["question"][1]["suggestedAnswer"].count)
      assert_equal(1, returned_data_hash["question"][0]["acceptedAnswer"].count)
      assert_equal(1, returned_data_hash["question"][1]["acceptedAnswer"].count)

      # check consistency of data in DB
      assert_equal(13, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(13, DataCycleCore::ClassificationCreativeWork.count)

      new_data_hash = returned_data_hash#.except("outputChannels")
      new_data_hash["question"] = []
      error = data_set.set_data_hash(new_data_hash)
      data_set.save

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(1, DataCycleCore::ClassificationCreativeWork.count)
    end

    test "generate a Quiz with questions and answers, then delete one question" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Quiz", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_hash = {
        "headline" => "Dies ist ein Test Quiz!",
        "alternativeHeadline" => "ein lustiges Quiz für jeden Tag!",
        "question" => [
        {
          "headline" => "beliebtestes Handy-OS?",
          "suggestedAnswer" => [
            { "text" => "Android" },
            { "text" => "iOS" },
            { "text" => "Sailfish"},
            { "text" => "Ubuntu Phone"}
          ],
          "acceptedAnswer" => [
            { "text" => "Android"}
          ]
        },
        {
          "headline" => "bestes Desktop OS?",
          "suggestedAnswer" => [
            { "text" => "Linux"},
            { "text" => "BSD"},
            { "text" => "Windows"},
            { "text" => "sonstige"}
          ],
          "acceptedAnswer" => [
            { "text" => "Linux"}
          ]
        }
        ]
      }
      expected_hash_quiz = {
        "kind" => [],
        "tags" => [],
        "state" => [],
        "season" => [],
        "topics" => [],
        "markets" => [],
        "headline" => "Dies ist ein Test Quiz!",
        "outputChannels" => [],
        "alternativeHeadline" => "ein lustiges Quiz für jeden Tag!"
       }

      error = data_set.set_data_hash(data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash

      assert_equal(0, error[:error].count)
      assert_equal(expected_hash_quiz, returned_data_hash.except("question","id","data_type").compact)
      assert_equal(2, returned_data_hash["question"].count)
      assert_equal(4, returned_data_hash["question"][0]["suggestedAnswer"].count)
      assert_equal(4, returned_data_hash["question"][1]["suggestedAnswer"].count)
      assert_equal(1, returned_data_hash["question"][0]["acceptedAnswer"].count)
      assert_equal(1, returned_data_hash["question"][1]["acceptedAnswer"].count)

      # check consistency of data in DB
      assert_equal(13, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(13, DataCycleCore::ClassificationCreativeWork.count)

      # leave one question alone, delete the second one incl. all related answers and classification_relations
      new_data_hash = returned_data_hash.except("question")
      new_data_hash["question"] = [{"id" => returned_data_hash['question'][0]['id']}]
      error = data_set.set_data_hash(new_data_hash)
      data_set.save

      # check consistency of data in DB
      assert_equal(7, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(7, DataCycleCore::ClassificationCreativeWork.count)
    end

  end
end
