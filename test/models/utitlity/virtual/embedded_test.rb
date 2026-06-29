# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Virtual
      class EmbeddedTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Virtual::Embedded
        end

        test 'map collects the configured key of each embedded object in its available locale' do
          embedded = struct_double(first_available_locale: :de, name: 'Embedded Name')
          relation = Struct.new(:items) {
            def includes(*_args) = items
          }.new([embedded])
          content = Struct.new(:relation) {
            def load_embedded_objects(*_args) = relation
          }.new(relation)

          value = subject.map(
            virtual_parameters: ['overlays'],
            virtual_definition: { 'virtual' => { 'key' => 'name' } },
            language: :de,
            content:
          )

          assert_equal(['Embedded Name'], value)
        end

        test 'map skips parameters without embedded objects' do
          content = Struct.new(:relation) {
            def load_embedded_objects(*_args) = relation
          }.new(Struct.new(:items) { def includes(*_args) = items }.new([]))

          value = subject.map(
            virtual_parameters: ['overlays'],
            virtual_definition: { 'virtual' => { 'key' => 'name' } },
            language: :de,
            content:
          )

          assert_equal([], value)
        end
      end
    end
  end
end
