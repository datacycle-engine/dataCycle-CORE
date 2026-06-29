# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class SlugTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Compute::Slug
        end

        test 'slug_value_from_first_existing_linked slugifies the first existing linked value' do
          content = Class.new {
            def id = nil
            def external_source_id = nil
            def translatable_property_names = []
            def slugify(value) = value.to_s.parameterize
          }.new

          value = subject.slug_value_from_first_existing_linked(
            content:,
            key: 'slug',
            computed_definition: { 'compute' => { 'parameters' => ['title'] } },
            computed_parameters: { 'title' => 'Hello World Slug' }
          )

          assert_equal('hello-world-slug', value)
        end
      end
    end
  end
end
