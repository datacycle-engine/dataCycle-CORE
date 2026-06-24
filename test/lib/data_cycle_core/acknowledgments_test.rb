# frozen_string_literal: true

require 'test_helper'
require 'data_cycle_core/acknowledgments'

module DataCycleCore
  class AcknowledgmentsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'extract_ruby_gem_infos collects metadata for every installed gem' do
      infos = DataCycleCore::Acknowledgments.extract_ruby_gem_infos

      assert_kind_of Array, infos
      assert_predicate infos, :any?
      assert(infos.all? { |info| info['type'] == 'gem' })
      assert(infos.all? { |info| info.key?('name') && info.key?('version') })
    end

    test 'extract_npm_package_infos parses yarn output into package infos' do
      yarn_list = { 'data' => { 'trees' => [{ 'name' => 'left-pad@1.3.0' }] } }.to_json
      yarn_info = { 'data' => { 'name' => 'left-pad', 'description' => 'pad', 'license' => 'MIT', 'homepage' => 'https://example.com' } }.to_json

      license_dir = ['node_modules/left-pad/LICENSE.md', 'node_modules/left-pad/NOTICE', 'node_modules/left-pad/index.js']

      DataCycleCore::Acknowledgments.stub(:`, ->(cmd) { cmd.include?('list') ? yarn_list : yarn_info }) do
        Dir.stub(:[], license_dir) do
          File.stub(:file?, true) do
            infos = DataCycleCore::Acknowledgments.extract_npm_package_infos

            assert_equal 1, infos.size
            assert_equal 'npm', infos.first['type']
            assert_equal 'left-pad', infos.first['name']
            assert_equal '1.3.0', infos.first['version']
            assert_equal ['LICENSE.md'], infos.first['license_files']
            assert_equal ['NOTICE'], infos.first['notice_files']
          end
        end
      end
    end

    test 'extract_npm_package_infos skips packages with invalid info json' do
      yarn_list = { 'data' => { 'trees' => [{ 'name' => 'broken@1.0.0' }] } }.to_json

      DataCycleCore::Acknowledgments.stub(:`, ->(cmd) { cmd.include?('list') ? yarn_list : 'not-json' }) do
        assert_empty DataCycleCore::Acknowledgments.extract_npm_package_infos
      end
    end

    test 'instance readers split packages by type' do
      packages = [
        { 'type' => 'gem', 'name' => 'rails' },
        { 'type' => 'npm', 'name' => 'left-pad' }
      ].to_json

      instance = DataCycleCore::Acknowledgments.new

      File.stub(:read, packages) do
        assert_equal 2, instance.packages.size
        assert_equal 1, instance.ruby_gems.size
        assert_equal 1, instance.npm_packages.size
      end
    end
  end
end
