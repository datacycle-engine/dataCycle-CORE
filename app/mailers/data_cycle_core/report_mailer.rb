# frozen_string_literal: true

module DataCycleCore
  class ReportMailer < ApplicationMailer
    def notify(identifier, format, recipients, params = {})
      report_class = DataCycleCore::Feature::ReportGenerator.by_identifier(identifier)
      params[:key] = identifier
      data, options = report_class.constantize.new(params:, locale: 'de').send(:"to_#{format}")

      attachments[options[:filename]] = {
        mime_type: Mime[format.to_sym],
        content: Base64.encode64(data),
        encoding: 'base64'
      }

      @identifier = identifier
      mail(to: recipients, subject: t("feature.report_generator.mailer.subject.#{params[:key] || 'downloads_popular'}", locale: DataCycleCore.ui_locales.first)) && return
    end
  end
end
