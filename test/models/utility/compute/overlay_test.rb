# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class OverlayTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Compute::Overlay
        end

        test 'overlay_present is false when no overlay attribute holds a value' do
          assert_not(subject.overlay_present(computed_parameters: {}))
          assert_not(subject.overlay_present(computed_parameters: { 'name_override' => nil, 'image_override' => [], 'tags_add' => [] }))
          assert_not(subject.overlay_present(computed_parameters: { 'name_override' => '' }))
        end

        test 'overlay_present is true for a present JSONB (string) override value' do
          assert(subject.overlay_present(computed_parameters: { 'name_override' => 'Overridden' }))
        end

        test 'overlay_present is true for a present linked/classification (array of ids) overlay value' do
          assert(subject.overlay_present(computed_parameters: { 'image_override' => ['00000000-0000-0000-0000-000000000001'] }))
          assert(subject.overlay_present(computed_parameters: { 'tags_add' => ['00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b'] }))
        end

        test 'overlay_present treats an explicit boolean false override as present' do
          # DataHashService.present?(false) == true: a deliberate false override is still an overlay
          assert(subject.overlay_present(computed_parameters: { 'flag_override' => false }))
        end

        test 'overlay_present is true when at least one of several attributes has a value' do
          assert(subject.overlay_present(computed_parameters: { 'name_override' => '', 'image_add' => ['00000000-0000-0000-0000-000000000001'] }))
        end
      end
    end
  end
end
