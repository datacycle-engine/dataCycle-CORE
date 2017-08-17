require 'test_helper'

DataCycleCore::Release.create!(
  release_code: 0,
  release_text: "freigegeben"
)
DataCycleCore::Release.create!(
  release_code: 1,
  release_text: "beim Partner"
)
DataCycleCore::Release.create!(
  release_code: 2,
  release_text: "in Bearbeitung"
)
DataCycleCore::Release.create!(
  release_code: 3,
  release_text: "in Review"
)
DataCycleCore::Release.create!(
  release_code: 4,
  release_text: "Draft"
)
DataCycleCore::Release.create!(
  release_code: 10,
  release_text: "gesperrt"
)

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
      ap data_set.extract_release(data_hash)
      error = data_set.set_data_hash(data_hash)
      data_set.save
      ap data_set.release
      ap data_set.get_data_hash
      assert_equal(data_hash, data_set.get_data_hash)
    end

  end
end
