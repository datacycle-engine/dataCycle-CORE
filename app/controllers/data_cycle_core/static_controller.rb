# frozen_string_literal: true

module DataCycleCore
  class StaticController < ApplicationController
    ROOT_PATHS = [Rails.root, DataCycleCore::Engine.root].freeze
    AUTHORIZED_FOLDERS = ['docs', 'guides', 'static'].freeze

    HTML_OPTIONS = {
      with_toc_data: true,
      hard_wrap: true
    }.freeze

    MARKDOWN_OPTIONS = {
      no_intra_emphasis: true,
      fenced_code_blocks: true,
      lax_spacing: true,
      autolink: true
    }.freeze

    def show
      @root_path = params[:root_path] || 'docs'
      raise ActiveRecord::RecordNotFound unless AUTHORIZED_FOLDERS.include?(@root_path)

      @markdown = render_markdown
    end

    def render_markdown
      full_paths = ROOT_PATHS.map { |p| p.join(@root_path, "#{sanitized_path}.{md,md.erb}") }
      markdown_path = Dir.glob(full_paths).first
      raise ActiveRecord::RecordNotFound if markdown_path.nil?

      raw_payload = render_to_string(inline: File.read(markdown_path))
      renderer = Redcarpet::Markdown.new(
        DataCycleCore::Static::MarkdownHtmlRenderer.new(**HTML_OPTIONS),
        **MARKDOWN_OPTIONS
      )

      renderer.render(raw_payload)
    end

    private

    def sanitized_path
      return 'overview' if params['path'].blank?

      decoded = CGI.unescape(params['path'])
      raise ActiveRecord::RecordNotFound if decoded.include?('..') || !%r{\A[a-zA-Z0-9_\-/]+\z}.match?(decoded)

      decoded
    end
  end
end
