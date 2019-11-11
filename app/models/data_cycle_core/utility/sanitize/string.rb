# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Sanitize
      module String
        class << self
          def format_html(string)
            disable_formatting = Nokogiri::XML::Node::SaveOptions::DEFAULT_HTML ^ Nokogiri::XML::Node::SaveOptions::FORMAT
            Loofah.fragment(string).to_html(save_with: disable_formatting)
          end
        end
      end
    end
  end
end
