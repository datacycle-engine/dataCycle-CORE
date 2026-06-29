# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Virtual
      class CreatorTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Virtual::Creator
        end

        test 'by_attribute_key returns the configured attribute of the creating user' do
          content = struct_double(created_by_user: struct_double(email: 'creator@example.com'))

          value = subject.by_attribute_key(content:, virtual_definition: { 'virtual' => { 'key' => 'email' } })

          assert_equal('creator@example.com', value)
        end

        test 'by_attribute_key returns nil when no key is configured' do
          assert_nil(subject.by_attribute_key(content: struct_double(created_by_user: nil), virtual_definition: { 'virtual' => {} }))
        end
      end
    end
  end
end
