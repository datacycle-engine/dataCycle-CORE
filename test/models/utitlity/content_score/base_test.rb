# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      class BaseTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::ContentScore::Base
        end

        test 'load_missing_values resolves embedded references to their data hashes' do
          content = Class.new {
            def get_data_hash_partial(_keys) = {}
            def embedded_property_names = ['overlays']
          }.new
          data_hash = {
            'overlays' => ['00000000-0000-0000-0000-000000000001', { 'id' => '00000000-0000-0000-0000-000000000002', 'extra' => 1 }, 'plain-string']
          }

          DataCycleCore::Thing.stub(:find_by, struct_double(get_data_hash: { 'name' => 'Found' })) do
            result = subject.load_missing_values(data_hash, content, ['overlays'])

            assert_equal({ 'name' => 'Found' }, result['overlays'][0])
            assert_equal({ 'name' => 'Found', 'id' => '00000000-0000-0000-0000-000000000002', 'extra' => 1 }, result['overlays'][1])
            assert_equal('plain-string', result['overlays'][2])
          end
        end

        test 'calculate_scores_by_method_or_presence delegates content_score properties and checks presence otherwise' do
          content = Class.new {
            def content_score_property_names = ['rating']
            def calculate_content_score(_key, _hash) = 0.8
          }.new

          scores = subject.calculate_scores_by_method_or_presence(content:, parameters: { 'rating' => 5, 'name' => 'present' })

          assert_in_delta(0.8, scores['rating'])
          assert_equal(1, scores['name'])
        end

        test 'load_linked replaces present ids with an ordered things relation' do
          parameters = { 'authors' => ['id-1', 'id-2'] }

          DataCycleCore::Thing.stub(:by_ordered_values, ['author-1', 'author-2']) do
            subject.load_linked(parameters, 'authors')
          end

          assert_equal(['author-1', 'author-2'], parameters['authors'])
        end

        test 'split_last splits on the last occurrence of the delimiter' do
          assert_equal(['a.b', 'c'], subject.split_last('a.b.c', '.'))
          assert_equal(['abc', nil], subject.split_last('abc', '.'))
        end

        test 'apply_overlays! overrides the base value with an override overlay' do
          content = overlay_content('override')
          data_hash = { 'name' => 'original', 'name_override' => 'new value' }

          subject.apply_overlays!(content, data_hash, ['name'])

          assert_equal('new value', data_hash['name'])
        end

        test 'apply_overlays! appends an add overlay to the base value' do
          content = overlay_content('add')
          data_hash = { 'name' => ['a'], 'name_override' => ['b'] }

          subject.apply_overlays!(content, data_hash, ['name'])

          assert_equal(['a', 'b'], data_hash['name'])
        end

        private

        def overlay_content(overlay_type)
          Class.new {
            def initialize(overlay_type) = (@overlay_type = overlay_type)
            def properties_with_overlay = ['name']
            def overlay_property_names_for(_key, **_opts) = ['name_override']
            def properties_for(_key) = { 'features' => { 'overlay' => { 'overlay_for' => 'name', 'overlay_type' => @overlay_type } } }
          }.new(overlay_type)
        end
      end
    end
  end
end
