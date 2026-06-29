# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Virtual
      class LinkedTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Virtual::Linked
        end

        test 'parent returns the first related content' do
          related = Class.new { def limit(_n) = ['parent-content'] }.new
          content = struct_double(related_contents: related)

          assert_equal(['parent-content'], subject.parent(content:))
        end

        test 'parent returns an empty relation without related contents' do
          assert_predicate(subject.parent(content: struct_double(related_contents: nil)), :empty?)
        end

        test 'in_radius returns an empty relation for a non-positive radius' do
          value = subject.in_radius(content: struct_double(location: nil), virtual_definition: { 'virtual' => { 'radius' => 0 } })

          assert_predicate(value, :empty?)
        end

        test 'in_radius returns an empty relation without coordinates' do
          value = subject.in_radius(content: struct_double(location: nil), virtual_definition: { 'virtual' => { 'radius' => 50 } })

          assert_predicate(value, :empty?)
        end

        test 'in_radius queries things around the content location and excludes configured properties' do
          query = radius_query_double
          stored_filter = Struct.new(:query) {
            def apply = query
          }.new(query)
          content = Class.new {
            def id = 'content-1'

            def try(key)
              case key.to_s
              when 'location' then Struct.new(:coordinates).new([11.0, 46.0])
              when 'linked_thing' then Struct.new(:nothing) { def pluck(_attribute) = ['excluded-1'] }.new(nil)
              end
            end
          }.new
          definition = { 'template_name' => 'POI', 'stored_filter' => {}, 'virtual' => { 'radius' => 50, 'unit' => 'km', 'limit' => 6, 'exclude_properties' => ['linked_thing'] } }

          DataCycleCore::StoredFilter.stub(:new, stored_filter) do
            assert_equal(['radius-result'], subject.in_radius(content:, virtual_definition: definition))
          end
        end

        test 'tour_start_location returns an empty relation without a template name' do
          assert_predicate(subject.tour_start_location(content: struct_double(line: nil), virtual_definition: {}), :empty?)
        end

        test 'tour_start_location returns an empty relation without a line' do
          assert_predicate(subject.tour_start_location(content: struct_double(line: nil), virtual_definition: { 'template_name' => 'POI' }), :empty?)
        end

        test 'tour_start_location builds a start location thing from the line start point' do
          factory = RGeo::Geographic.spherical_factory(srid: 4326)
          line = factory.line_string([factory.point(11.0, 46.0), factory.point(11.1, 46.1)])
          content = struct_double(id: '00000000-0000-0000-0000-000000000001', line:)

          value = subject.tour_start_location(content:, virtual_definition: { 'template_name' => 'POI' })

          assert_equal('POI', value.first&.template_name)
        end

        private

        def radius_query_double
          query = Class.new do
            def where(*_args, **_kwargs) = self
            def limit(_n) = self
            def geo_radius(_options) = self
            def sort_proximity_geographic(_direction, _coordinates) = self
            def query = ['radius-result']
            define_method(:not) { |*_args, **_kwargs| self }
          end
          query.new
        end
      end
    end
  end
end
