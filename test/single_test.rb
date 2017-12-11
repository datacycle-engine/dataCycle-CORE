require 'test_helper'

module DataCycleCore
  class SingleTest < ActiveSupport::TestCase

    test "faulty test" do

      cw_temp = DataCycleCore::CreativeWork.count

      template = DataCycleCore::CreativeWork.find_by(template: true, headline: "CreativeWorkEmbeddedLinkUser", description: "CreativeWork")
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save

      temp = DataCycleCore::User.create!(
        given_name: 'test',
        email: 'test@pixelpoint.at',
        admin: true,
        external: false,
        password: 'k2*8NTxhrU2VDXqH',
        role_id: DataCycleCore::Role.order('rank DESC').first.id
      )

      data_hash = {"headline" => "Dies ist ein Test!", "linked" => temp.id}

      data_set.set_data_hash(data_hash: data_hash, current_user: temp)
      data_set.save

      assert_equal(1, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(1, DataCycleCore::ContentContent.count)
      assert_equal(data_hash, data_set.get_data_hash.except('id'))
    end

  end
end
