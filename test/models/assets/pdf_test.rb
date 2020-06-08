# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Assets
    class PdfTest < ActiveSupport::TestCase
      def setup
        DataCycleCore::PdfUploader.enable_processing = true
        @pdf_temp = DataCycleCore::Pdf.count
      end

      def upload_pdf(file_name)
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'pdf', file_name)
        @pdf = DataCycleCore::Pdf.new(file: File.open(file_path))
        @pdf.save

        assert(@pdf.persisted?)
        assert(@pdf.valid?)

        @pdf.reload
      end

      def validate_pdf(file_name)
        # check consistency of data in DB
        assert_equal(1, DataCycleCore::Pdf.count)
        # check pdf data
        assert(@pdf.file_size.positive?)
        assert_equal(file_name, @pdf.name)
        assert_equal('DataCycleCore::Pdf', @pdf.type)
        assert(@pdf.metadata.is_a?(Hash))
      end

      test 'upload Pdf: pdf' do
        file_name = 'test.pdf'
        upload_pdf file_name
        assert_equal('application/pdf', @pdf.content_type)

        validate_pdf file_name
      end

      test 'upload invalid Pdf: .jpg' do
        file_name = 'test_rgb.jpg'
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', file_name)
        @pdf = DataCycleCore::Pdf.new(file: File.open(file_path))
        @pdf.save

        assert_not(@pdf.persisted?)
        assert_not(@pdf.valid?)
        assert(@pdf.errors.present?)
      end

      def teardown
        @pdf.remove_file!
        @pdf.destroy!
        DataCycleCore::PdfUploader.enable_processing = false
      end
    end
  end
end
