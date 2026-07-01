# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Serialize
    module Serializer
      # Coverage for the abstract Serialize::Serializer::Base class methods and
      # the file_name fallbacks (asset basename / template-name + uuid).
      class BaseCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Serialize::Serializer::Base
        end

        test 'abstract class methods raise NotImplementedError' do
          assert_raises(NotImplementedError) { subject.translatable? }
          assert_raises(NotImplementedError) { subject.mime_type }
          assert_raises(NotImplementedError) { subject.serialize_thing(content: nil, language: nil) }
          assert_raises(NotImplementedError) { subject.serialize_watch_list(content: nil, language: nil) }
          assert_raises(NotImplementedError) { subject.serialize_stored_filter(content: nil, language: nil) }
        end

        test 'file_name falls back to the asset file basename when there is no title' do
          content = struct_double(title: nil, name: nil, asset: struct_double(file: struct_double(path: '/uploads/sample_image.jpg')))

          assert_equal('sample_image.jpg', subject.file_name(content:).to_s)
        end

        test 'file_name falls back to template name plus a uuid without title or asset' do
          content = struct_double(title: nil, name: nil, asset: nil, template_name: 'POI')

          assert_match(/\APOI_/, subject.file_name(content:).to_s)
        end
      end
    end
  end
end
