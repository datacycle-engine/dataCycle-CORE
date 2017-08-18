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
      value_hash, release_hash = data_set.extract_release(data_hash)
      ap [value_hash,release_hash]

      ap data_set.merge_release(value_hash, release_hash)

    end
  end
end
