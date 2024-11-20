# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Oembed
        class << self
          def dc_url(thing)
            template = DataCycleCore::ThingTemplate.find_by(template_name: thing[:content].template_name)
            return nil if thing.blank? || template.blank? || DataCycleCore.oembed_providers['oembed_providers'].flat_map { |provider| provider['output']&.flat_map { |output| output['template_names'] } }.compact.exclude?(template.template_name)
            thing_id = thing[:content][:id]
            host = Rails.application.config.action_mailer.default_url_options[:host]
            protocol = Rails.application.config.action_mailer.default_url_options[:protocol]
            "#{protocol}://#{host}/oembed?thing_id=#{thing_id}"
          end

          def fetch(thing)
            return nil if thing.blank? || thing[:content]&.id.blank?
            DataCycleCore::MasterData::Validators::Oembed.valid_oembed_from_thing_id(thing[:content].id)&.dig(:oembed)
          end
        end
      end
    end
  end
end
