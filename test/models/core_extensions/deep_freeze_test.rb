# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DeepFreezeTest < ActiveSupport::TestCase
    setup do
      @hash1 = {
        tmp1: 'test',
        tmp2: {
          tmp3: 'test2',
          tmp4: ['test3', 'test4'],
          tmp5: {
            tmp6: nil
          }
        },
        tmp7: ['test5', 'test6', 'test7'],
        tmp8: Time.zone.now,
        tmp9: DataCycleCore::ThingTemplate.all,
        tmp10: [
          {
            tmp11: 'test8'
          }
        ]
      }.deep_freeze
    end

    test 'hash deep freeze' do
      assert_raise { @hash1[:tmp1] << 'fail' }
      assert_raise { @hash1[:tmp2][:tmp3] << 'fail' }
      assert_raise { @hash1[:tmp2][:tmp3][:tmp5][:tmp6] = 'fail' }
      assert_raise { @hash1[:tmp2][:tmp4] << 'fail' }
      assert_raise { @hash1[:tmp7] << 'fail' }
      assert_raise { @hash1[:tmp8] += 1.day }
      assert_raise { @hash1[:tmp9] = @hash1[:tmp9].pluck(:template_name) }
      assert_raise { @hash1[:tmp10][0][:tmp11] << 'fail' }
    end
  end
end
