# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Virtual
      class OembedTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Virtual::Oembed
        end

        test 'url_options returns the configured default url options' do
          assert_equal(Rails.application.config.action_mailer.default_url_options, subject.url_options)
        end

        test 'dc_url returns nil without content' do
          assert_nil(subject.dc_url(content: nil))
        end

        test 'dc_url builds an oembed url for an allowed template name' do
          providers = { 'oembed_providers' => [{ 'output' => [{ 'template_names' => ['Artikel'] }] }] }
          content = struct_double(template_name: 'Artikel', id: 'thing-1')

          DataCycleCore.stub(:oembed_providers, providers) do
            subject.stub(:oembed_url, 'https://oembed.test/thing-1') do
              assert_equal('https://oembed.test/thing-1', subject.dc_url(content:))
            end
          end
        end

        test 'dc_url returns nil for a template that is not an oembed provider' do
          providers = { 'oembed_providers' => [{ 'output' => [{ 'template_names' => ['Artikel'] }] }] }
          content = struct_double(template_name: 'Bild', id: 'thing-1')

          DataCycleCore.stub(:oembed_providers, providers) do
            assert_nil(subject.dc_url(content:))
          end
        end

        test 'fetch returns nil without a content id' do
          assert_nil(subject.fetch(content: struct_double(id: nil)))
        end

        test 'fetch resolves the oembed data by thing id' do
          validator = Class.new { def valid_oembed_from_thing_id(_id) = { oembed: { 'type' => 'rich' } } }.new
          content = struct_double(id: 'thing-1')

          DataCycleCore::MasterData::Validators::Oembed.stub(:new, validator) do
            value = subject.fetch(content:, virtual_definition: { 'virtual' => { 'identifier' => 'id' } })

            assert_equal({ 'type' => 'rich' }, value)
          end
        end

        test 'fetch extracts the thing id from a things url' do
          validator = Class.new { def valid_oembed_from_thing_id(_id) = { oembed: 'oembed-data' } }.new
          content = struct_double(id: 'ignored', url: 'https://example.test/things/00000000-0000-0000-0000-000000000abc')

          DataCycleCore::MasterData::Validators::Oembed.stub(:new, validator) do
            value = subject.fetch(content:, virtual_definition: { 'virtual' => { 'identifier' => 'url' } })

            assert_equal('oembed-data', value)
          end
        end
      end
    end
  end
end
