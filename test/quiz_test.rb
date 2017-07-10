require 'test_helper'

# load template, classifications for all tests
creative_work_yaml = Rails.root.join('..','setup_data','creative_works.yml')
DataCycleCore::MasterData::ImportTemplates.new.import(creative_work_yaml, DataCycleCore::CreativeWork)
classification_yaml = Rails.root.join('..','setup_data','classifications.yml')
DataCycleCore::MasterData::ImportClassifications.new.import(classification_yaml)

module DataCycleCore
  class QuizTest < ActiveSupport::TestCase

    test "CreativeWork exists" do
      data = DataCycleCore::CreativeWork.new
      assert_equal(data.class, DataCycleCore::CreativeWork)
    end

    test "generate a Quiz" do
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
      error = data_set.set_data_hash(data_hash)
      ap error
      data_set.save
      returned_data_hash = data_set.get_data_hash

      ap returned_data_hash
    end

  end
end
