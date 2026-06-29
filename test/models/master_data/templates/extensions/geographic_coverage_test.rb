# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module MasterData
    module Templates
      module Extensions
        # Coverage for the Geographic template-priority helpers - pure logic over a
        # properties hash that records validation errors / assigns overlay priorities.
        # Driven through a tiny host object that mixes in the module and exposes @errors.
        class GeographicCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
          def host
            Class.new {
              include DataCycleCore::MasterData::Templates::Extensions::Geographic

              attr_reader :errors

              def initialize
                @errors = []
              end
            }.new
          end

          test 'priorities_present? records an error for a geographic property without a priority' do
            subject = host

            assert_not subject.send(:priorities_present?, { 'location' => { type: 'geographic' } }, 'set.template')
            assert_predicate subject.errors, :present?
          end

          test 'priorities_unique? records an error when two geographic properties share a priority' do
            subject = host
            properties = {
              'a' => { type: 'geographic', priority: 1 },
              'b' => { type: 'geographic', priority: 1 }
            }

            assert_not subject.send(:priorities_unique?, properties, 'set.template')
            assert_predicate subject.errors, :present?
          end

          test 'add_priority_for_overlay_properties! inherits the base priority and renumbers' do
            subject = host
            properties = {
              'base' => { type: 'geographic', priority: 5 },
              'overlay' => { type: 'geographic', features: { overlay: { overlay_for: 'base' } } }
            }

            subject.send(:add_priority_for_overlay_properties!, properties)

            assert(properties.values.all? { |v| v[:priority].present? })
          end
        end
      end
    end
  end
end
