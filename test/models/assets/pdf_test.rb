# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Assets
    class PdfTest < ActiveSupport::TestCase
      include DataCycleCore::ActiveStorageHelper

      def setup
        @pdf_temp = DataCycleCore::Pdf.count
      end

      def validate_pdf(file_name)
        # check consistency of data in DB
        assert_equal(1, DataCycleCore::Pdf.count)
        # check pdf data
        assert_predicate(@pdf.file_size, :positive?)
        assert_equal(file_name, @pdf.name)
        assert_equal('DataCycleCore::Pdf', @pdf.type)
        assert(@pdf.metadata.is_a?(Hash))
        assert_predicate(@pdf.metadata['content'], :present?)
        assert(@pdf.metadata['metadata'].is_a?(Hash))
        assert_predicate(@pdf.metadata['metadata'], :present?)
      end

      test 'upload Pdf: pdf' do
        file_name = 'test.pdf'
        @pdf = upload_pdf(file_name)

        assert_equal('application/pdf', @pdf.content_type)

        validate_pdf file_name
      end

      test 'upload invalid Pdf: .jpeg' do
        file_name = 'test_rgb.jpeg'
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', file_name)
        @pdf = DataCycleCore::Pdf.new
        @pdf.file.attach(io: File.open(file_path), filename: file_name)
        @pdf.save

        assert_not(@pdf.persisted?)
        assert_not(@pdf.valid?)
        assert_predicate(@pdf.errors, :present?)
      end
    end
  end
end
