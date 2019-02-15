# frozen_string_literal: true

module DataCycleCore
  class DocumentationController < ApplicationController
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

      if image_path
        send_file image_path
      else
        render status: :not_found, file: Rails.root.join('public', '404.html'), layout: false
      end
    end

    def render_markdown
      markdown_path = view_paths.map(&:to_path).map { |p|
        (p.split('/')[0..-3] + ['docs']).join('/')
      }.map { |p|
        File.join(p, sanitized_path + '.md')
      }.detect do |p|
        File.file?(p)
      end

      markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML,
                                         no_intra_emphasis: true,
                                         fenced_code_blocks: true)

      markdown.render(File.read(markdown_path)) if markdown_path
    end

    def sanitized_path
      sanitize(params['path']) if params.dig('path').present?
    end

    def sanitized_file
      sanitize(params['file']) if params.dig('file').present?
    end

    def sanitize(string)
      ActionController::Base.helpers.sanitize(string)
    end
  end
end
