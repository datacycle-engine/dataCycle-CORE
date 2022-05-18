# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Content
    class ComputedPropertiesUpdateTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
      end

      test 'it should work' do
        @organization = DataCycleCore::TestPreparations.create_content(
          template_name: 'Organization',
          data_hash: { name: 'Test Organization 1' }
        )
        @person = DataCycleCore::TestPreparations.create_content(
          template_name: 'Person',
          data_hash: {
            given_name: 'Test',
            family_name: 'Person 1',
            member_of: [@organization.id]
          }
        )
        @image = DataCycleCore::TestPreparations.create_content(
          template_name: 'ImageWithComputedAttribute',
          data_hash: {
            name: 'Test Bild 1',
            author: [@person.id],
            copyright_holder: [@organization.id]
          }
        )

<<<<<<< HEAD
        assert_equal('(c) Test Organization 1 / Test Person 1', @image.copyright_notice)
=======
        assert_equal('(c) Test Person 1 / Test Organization 1', @image.copyright_notice_override || @image.copyright_notice_computed)
>>>>>>> old/develop

        @organization.set_data_hash(data_hash: @organization.get_data_hash.merge({
          'name' => 'Test Organization 1 - UPDATED'
        }))

        @image = DataCycleCore::Thing.find(@image.id)

<<<<<<< HEAD
        assert_equal('(c) Test Organization 1 - UPDATED / Test Person 1', @image.copyright_notice)
=======
        assert_equal('(c) Test Person 1 / Test Organization 1 - UPDATED', @image.copyright_notice_override || @image.copyright_notice_computed)
>>>>>>> old/develop
      end
    end
  end
end
