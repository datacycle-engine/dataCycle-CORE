# frozen_string_literal: true

module DataCycleCore
  class FilterNoreply
    def self.delivering_email(message)
      message.to  = remove_noreply(message.to)
      message.cc  = remove_noreply(message.cc)
      message.bcc = remove_noreply(message.bcc)

      message.perform_deliveries = false if no_recipients_left?(message)
      message
    end

    def self.noreply?(email)
      email.to_s.downcase.match?(/\A(no[-_]?reply|donotreply)/)
    end

    def self.remove_noreply(emails)
      Array.wrap(emails).reject { |email| noreply?(email) }
    end

    def self.no_recipients_left?(message)
      [message.to, message.cc, message.bcc].all?(&:blank?)
    end
  end
end
