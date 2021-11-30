# frozen_string_literal: true

module DataCycleCore
  class DocumentationController < ApplicationController
    HTML_OPTIONS = {
      with_toc_data: true
    }.freeze

    MARKDOWN_OPTIONS = {
      no_intra_emphasis: true,
      fenced_code_blocks: true
    }.freeze

    def show
      @markdown = render_markdown
    end

    def image
      image_path = view_paths.map(&:to_path).map { |p|
        p.split('/')[0..-3].join('/')
      }.map { |p|
        File.join(p, request.path)
      }.detect do |p|
        File.file?(p)
      end

      raise ActiveRecord::RecordNotFound unless image_path

      send_file image_path
    end

    def render_markdown
      markdown_path = view_paths.map(&:to_path).map { |p|
        (p.split('/')[0..-3] + ['docs']).join('/')
      }.map { |p|
        File.join(p, sanitized_path + '.md')
      }.detect do |p|
        File.file?(p)
      end

      markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(HTML_OPTIONS), MARKDOWN_OPTIONS)

      raise ActiveRecord::RecordNotFound if markdown_path.nil?

      markdown.render(File.read(markdown_path))
    end

    def sanitized_path
      if params.dig('path').present?
        sanitize(params['path'])
      else
        'overview'
      end
    end

    def sanitized_file
      sanitize(params['file']) if params.dig('file').present?
    end

    def sanitize(string)
      ActionController::Base.helpers.sanitize(string)
    end
  end
end
