# frozen_string_literal: true

module DataCycleCore
  class StaticController < ApplicationController
    ROOT_PATHS = [Rails.root, DataCycleCore::Engine.root].freeze
    HTML_OPTIONS = {
      with_toc_data: true
    }.freeze

    MARKDOWN_OPTIONS = {
      no_intra_emphasis: true,
      fenced_code_blocks: true
    }.freeze

    def show
      @root_path = params[:root_path] || 'docs'
      @markdown = render_markdown
    end

    def image
      root_paths = ROOT_PATHS.map { |p| p.join(*request.path.split('/')) }
      image_path = root_paths.detect(&:exist?)

      raise ActiveRecord::RecordNotFound unless image_path

      send_file image_path
    end

    def render_markdown
      root_paths = ROOT_PATHS.map { |p| p.join(@root_path, sanitized_path + '.md') }
      markdown_path = root_paths.detect(&:exist?)

      raise ActiveRecord::RecordNotFound if markdown_path.nil?

      markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(HTML_OPTIONS), MARKDOWN_OPTIONS)
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
