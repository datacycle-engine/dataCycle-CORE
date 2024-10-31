# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Oembed
        class << self
          def dc_url(thing)
            template = DataCycleCore::ThingTemplate.find_by(template_name: thing[:content].template_name)
            return nil if template.blank? || template['schema'].dig('features', 'oembed', 'allowed') != true
            thing_id = thing[:content][:id]
            host = Rails.application.config.action_mailer.default_url_options[:host]
            protocol = Rails.application.config.action_mailer.default_url_options[:protocol]
            "#{protocol}://#{host}/oembed?thing_id=#{thing_id}"
          end
        end
      end
    end
  end
end
