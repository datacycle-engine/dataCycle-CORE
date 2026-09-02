# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DuplicateCandidateOriginalForMergeTest < DataCycleCore::TestCases::ActiveSupportTestCase
    ID_A = '6a2ee0a2-0c8f-4b0e-9c96-2e2a0a2f6e0a'
    ID_B = '6a2ee0a2-0c8f-4b0e-9c96-2e2a0a2f6e0b'

    # a content whose translated internal_content_score differs per locale
    class LocalizedContent
      attr_reader :id, :updated_at

      def initialize(id, scores, updated_at: Time.zone.now)
        @id = id
        @scores = scores
        @updated_at = updated_at
      end

      def available_locales
        @scores.keys
      end

      def internal_content_score
        @scores[I18n.locale]
      end
    end

    def subject
      DataCycleCore::Feature::DuplicateCandidate
    end

    test 'the content with the highest content score becomes the original' do
      low = content(ID_A, score: 20)
      high = content(ID_B, score: 80)

      assert_equal high, subject.original_for_merge([low, high])
      assert_equal high, subject.original_for_merge([high, low])
    end

    test 'the content edited last becomes the original on an equal content score' do
      older = content(ID_A, score: 50, updated_at: 2.days.ago)
      newer = content(ID_B, score: 50, updated_at: 1.hour.ago)

      assert_equal newer, subject.original_for_merge([newer, older])
    end

    test 'a content without the ContentScore feature scores zero' do
      unscored = struct_double(id: ID_A, updated_at: Time.zone.now)
      scored = content(ID_B, score: 1)

      assert_in_delta 0.0, subject.content_score_for_merge(unscored)
      assert_equal scored, subject.original_for_merge([unscored, scored])
    end

    test 'the maximum content score over the available locales counts' do
      scores = I18n.available_locales.index_with { |locale| locale == I18n.available_locales.last ? 90 : 10 }

      assert_in_delta 90.0, subject.content_score_for_merge(LocalizedContent.new(ID_A, scores))
    end

    test 'locales without a content score are ignored' do
      scores = I18n.available_locales.index_with(nil).merge(I18n.available_locales.first => 40)

      assert_in_delta 40.0, subject.content_score_for_merge(LocalizedContent.new(ID_A, scores))
    end

    private

    def content(id, score:, updated_at: Time.zone.now)
      LocalizedContent.new(id, I18n.available_locales.index_with(score), updated_at:)
    end
  end
end
