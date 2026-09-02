# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DocumentationTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
    end

    test 'docs path' do
      get '/docs/classifications'

      assert_response :success
    end

    # Redcarpet only parses GFM tables when the tables extension is enabled, and it fails silently:
    # without it the pipes are rendered as paragraph text instead of a table.
    test 'markdown tables are rendered as tables' do
      DataCycleCore::Engine.root.glob('docs/**/*.md').each do |file|
        # fenced blocks are excluded: json_ld.md shows form fields as a literal pipe listing
        next unless file.read.gsub(/^```.*?^```/m, '').match?(/^\|[-: ]+\|/)

        path = file.relative_path_from(DataCycleCore::Engine.root.join('docs')).sub_ext('').to_s

        get "/docs/#{path}"

        assert_response :success, "GET /docs/#{path} failed"
        assert_includes response.body, '<table>', "no table rendered in /docs/#{path}"
      end
    end
  end
end
