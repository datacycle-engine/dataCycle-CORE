# frozen_string_literal: true

require 'test_helper'
require 'virtual_attributes_test_utilities'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe 'DataCycleCore::Utility::Virtual::Common#content_classification_for_tree' do
  include VirtualAttributeTestUtilities

  subject do
    DataCycleCore::Utility::Virtual::Common
  end

  it 'should call Content#classification_aliases_for_tree' do
    content = Minitest::Mock.new
    content.expect(:classifications_for_tree, [], tree_name: 'My Classificaton Tree')

    subject.content_classification_for_tree(virtual_definition: { 'tree_label' => 'My Classificaton Tree' }, content: content)

    assert_mock(content)
  end
end
