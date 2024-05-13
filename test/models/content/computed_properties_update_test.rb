# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Content
    class ComputedPropertiesUpdateTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        @organization = DataCycleCore::TestPreparations.create_content(
          template_name: 'Organization',
          data_hash: { name: 'Test Organization 1' }
        )

        @organization2 = DataCycleCore::TestPreparations.create_content(
          template_name: 'Organization',
          data_hash: { name: 'Test Organization 2' }
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
        I18n.with_locale(:en) { @image.set_data_hash(data_hash: { name: 'Test Name English' }) }
      end

      test 'update copyright_notice' do
        assert_equal('(c) Test Person 1 / Test Organization 1', @image.copyright_notice)

        @organization.set_data_hash(data_hash: @organization.get_data_hash.merge({
          'name' => 'Test Organization 1 - UPDATED'
        }))

        @image = DataCycleCore::Thing.find(@image.id)

        assert_equal('(c) Test Person 1 / Test Organization 1 - UPDATED', @image.copyright_notice)
      end

      test 'update computed with partial hash and missing linked' do
        @image.set_data_hash(data_hash: @image.get_data_hash.except(*@image.computed_property_names).except('author').merge({
          'name' => 'Test Bild 1 - UPDATED'
        }))

        assert_equal('(c) Test Person 1 / Test Organization 1', @image.copyright_notice_override || @image.copyright_notice_computed)
      end

      test 'update copyright_holder updates translated attribution_name in all languages' do
        @image.set_data_hash_with_translations(data_hash: { copyright_holder: [@organization2.id] })

        assert_equal '(c) Test Organization 2 / Test Person 1', I18n.with_locale(:de) { @image.attribution_name }
        assert_equal '(c) Test Organization 2 / Test Person 1', I18n.with_locale(:en) { @image.reload.attribution_name }
      end
    end
  end
end
