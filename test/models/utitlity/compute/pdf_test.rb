# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class PdfTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Compute::Pdf
        end

        test 'width and height are not implemented and return nil' do
          assert_nil(subject.width(computed_parameters: {}))
          assert_nil(subject.height(computed_parameters: {}))
        end

        test 'exif_value reads a metadata path from the pdf' do
          pdf = struct_double(metadata: { 'pdf_properties' => { 'pages' => 7 } })

          DataCycleCore::Pdf.stub(:find_by, pdf) do
            assert_equal(7, subject.exif_value('pdf-id', ['pdf_properties', 'pages']))
          end
        end

        test 'exif_value returns nil for a missing pdf or a blank path' do
          DataCycleCore::Pdf.stub(:find_by, nil) do
            assert_nil(subject.exif_value('missing', ['pages']))
          end

          DataCycleCore::Pdf.stub(:find_by, struct_double(metadata: {})) do
            assert_nil(subject.exif_value('pdf-id', nil))
          end
        end

        test 'extract_content returns the content metadata' do
          pdf = struct_double(metadata: { 'content' => 'extracted text' })

          DataCycleCore::Pdf.stub(:find_by, pdf) do
            assert_equal('extracted text', subject.extract_content(computed_parameters: { 'asset' => 'pdf-id' }))
          end
        end

        test 'extract_content returns nil when the pdf is missing' do
          DataCycleCore::Pdf.stub(:find_by, nil) do
            assert_nil(subject.extract_content(computed_parameters: { 'asset' => 'missing' }))
          end
        end

        test 'thumbnail_url returns nil when the pdf has no attached file' do
          DataCycleCore::Pdf.stub(:find_by, struct_double(file: unattached_file)) do
            assert_nil(subject.thumbnail_url(computed_parameters: { 'asset' => 'pdf-id' }))
          end
        end

        test 'preview_url returns nil when the pdf has no attached file' do
          DataCycleCore::Pdf.stub(:find_by, struct_double(file: unattached_file)) do
            assert_nil(subject.preview_url(computed_parameters: { 'asset' => 'pdf-id' }))
          end
        end

        private

        def unattached_file
          Class.new { def attached? = false }.new
        end
      end
    end
  end
end
