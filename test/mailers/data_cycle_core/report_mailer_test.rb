# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ReportMailerTest < DataCycleCore::TestCases::ActiveSupportTestCase
    class FakeReport
      def initialize(params:, locale:)
        @params = params
        @locale = locale
      end

      def to_pdf
        ['raw-report-data', { filename: 'report.pdf' }]
      end
    end

    test 'notify attaches the generated report and builds a mail' do
      DataCycleCore::Feature::ReportGenerator.stub(:by_identifier, ['DataCycleCore::ReportMailerTest::FakeReport', {}]) do
        mail = DataCycleCore::ReportMailer.notify('downloads_popular', 'pdf', ['admin@datacycle.at'])

        assert_equal ['admin@datacycle.at'], mail.to
        assert_predicate mail.subject, :present?
        assert_includes mail.attachments.map(&:filename), 'report.pdf'
      end
    end
  end
end
