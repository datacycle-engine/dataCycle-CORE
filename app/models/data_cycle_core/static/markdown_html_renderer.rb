# frozen_string_literal: true

module DataCycleCore
  module Static
    class MarkdownHtmlRenderer < Redcarpet::Render::HTML
      include Rails.application.routes.mounted_helpers

      def link(link, title, content)
        link = File.join(data_cycle_core.root_path, link) if link.start_with?('/') && !link.start_with?(data_cycle_core.root_path)

        "<a href=\"#{link}\"#{" title=\"#{title}\"" if title.present?}>#{content}</a>"
      end
    end
  end
end
