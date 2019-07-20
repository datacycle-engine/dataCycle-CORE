# frozen_string_literal: true

require 'test_helper'
require 'minitest/autorun'

module DataCycleCore
  class SchemaTest < ActiveSupport::TestCase
    test 'DataCycleCore::Schema should provide list of available content types' do
      assert_equal(['container', 'entity', 'embedded'].sort, DataCycleCore::Schema.content_types.sort)
    end

    test 'DataCycleCore::Schema should provide list of templates for given content type' do
      assert_includes(DataCycleCore::Schema.templates_with_content_type('container').map(&:template_name), 'Container')

      assert_includes(DataCycleCore::Schema.templates_with_content_type('entity').map(&:template_name), 'Artikel')
      assert_includes(DataCycleCore::Schema.templates_with_content_type('entity').map(&:template_name), 'Örtlichkeit')
      assert_includes(DataCycleCore::Schema.templates_with_content_type('entity').map(&:template_name), 'Event')
    end
  end
end
