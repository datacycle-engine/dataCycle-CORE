# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    class DuplicateContentTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
      before(:all) do
        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
      end

      setup do
        sign_in(User.find_by(email: 'tester@datacycle.at'))
      end

      test 'create duplicate of content' do
        get create_duplication_thing_path(@content), params: {}, headers: {
          referer: thing_path(@content)
        }

        assert_response :found
        duplicate = DataCycleCore::Thing.where_translated_value(name: "DUPLICATE: #{@content.name}").first
        assert duplicate.present?
        assert_not_equal @content.id, duplicate.id
      end
    end
  end
end
