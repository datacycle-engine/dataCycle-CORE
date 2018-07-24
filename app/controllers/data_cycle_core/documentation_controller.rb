# frozen_string_literal: true

module DataCycleCore
  class DocumentationController < ApplicationController
    def show
      @markdown = render_markdown
    end

    def render_markdown
      markdown_path = view_paths.map(&:to_path).map { |p|
        (p.split('/')[0..-3] + ['docs']).join('/')
      }.map { |p|
        File.join(p, params['path'] + '.md')
      }.select { |p|
        File.file?(p)
      }.first

      markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)

      markdown.render(File.read(markdown_path)) if markdown_path
    end
  end
end
