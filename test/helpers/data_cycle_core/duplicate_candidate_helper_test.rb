# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DuplicateCandidateHelperTest < ActionView::TestCase
    include DataCycleCore::DuplicateCandidateHelper
    include DataCycleCore::UiLocaleHelper

    test 'duplicate_score_tag is nil without candidates' do
      assert_nil duplicate_score_tag(nil)
      assert_nil duplicate_score_tag([])
    end

    test 'duplicate_score_tag shows the highest score and a tooltip with all candidates' do
      candidates = [
        struct_double(score: 50, duplicate_module: DataCycleCore::Thing),
        struct_double(score: 90, duplicate_module: DataCycleCore::Thing)
      ]

      html = duplicate_score_tag(candidates)

      assert_includes html, '>90</b>'
      assert_includes html, 'data-dc-tooltip'
    end
  end
end
