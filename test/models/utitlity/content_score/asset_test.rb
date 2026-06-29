# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      class AssetTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::ContentScore::Asset
        end

        test 'by_mime_types scores 1 for an allowed mime type' do
          definition = { 'content_score' => { 'mime_types' => ['image/jpeg', 'image/png'] } }

          assert_equal(1, subject.by_mime_types(definition:, parameters: { 'content_type' => 'image/jpeg' }, key: 'content_type'))
        end

        test 'by_mime_types scores 0 for a disallowed mime type' do
          definition = { 'content_score' => { 'mime_types' => ['image/jpeg'] } }

          assert_equal(0, subject.by_mime_types(definition:, parameters: { 'content_type' => 'application/pdf' }, key: 'content_type'))
        end

        test 'to_tooltip lists the allowed mime types as html' do
          definition = { 'content_score' => { 'method' => 'by_mime_types', 'mime_types' => ['image/jpeg', 'image/png'] } }

          tooltip = subject.to_tooltip(nil, definition, :de)

          assert_includes(tooltip, '<li><b>image/jpeg</b></li>')
        end

        test 'to_tooltip delegates to the base tooltip for other methods' do
          assert_nothing_raised do
            subject.to_tooltip(nil, { 'content_score' => { 'method' => 'by_quantity' } }, :de)
          end
        end
      end
    end
  end
end
