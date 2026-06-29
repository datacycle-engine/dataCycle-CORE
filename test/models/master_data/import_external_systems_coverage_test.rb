# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module DataCycleCore
  # Focused coverage for the pure data-transformation helpers, the empty/error
  # load paths and the embedded validation contracts of ImportExternalSystems
  # that the fixture-driven spec does not reach. Named distinctly to avoid a
  # parallel_tests test-class collision with the existing spec.
  class ImportExternalSystemsCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def subject = DataCycleCore::MasterData::ImportExternalSystems

    # --- pure transformation helpers --------------------------------------------------

    test 'add_export_defaults! recurses into hashes and transforms scalar leaves' do
      data = { 'h' => { 'strategy' => 'Foo' }, 's' => 'plain' }
      result = subject.add_export_defaults!(data, 'DataCycleCore::Export::Generic')

      assert_same data, result
      assert_equal 'plain', data['s'] # not a module-path property -> untouched
      assert_kind_of String, data['h']['strategy'] # module-path property -> namespaced
    end

    test 'add_export_defaults! returns early for blank data' do
      assert_nil subject.add_export_defaults!(nil, 'DataCycleCore::Export::Generic')
    end

    test 'sort_steps_by_position! keeps a step whose position has neither before nor after' do
      steps = { 's1' => { 'position' => { 'foo' => 'bar' } }, 's2' => { 'x' => 1 } }

      # an unresolvable position must leave the step in place, not drop it
      assert_equal ['s1', 's2'], subject.sort_steps_by_position!(steps).keys
    end

    test 'sort_steps_by_position! keeps a step whose after/before references a missing step' do
      after_missing = { 's1' => { 'position' => { 'after' => 'nope' } }, 's2' => { 'x' => 1 } }
      before_missing = { 's1' => { 'position' => { 'before' => 'nope' } }, 's2' => { 'x' => 1 } }

      assert_equal ['s1', 's2'], subject.sort_steps_by_position!(after_missing).keys
      assert_equal ['s1', 's2'], subject.sort_steps_by_position!(before_missing).keys
    end

    test 'sort_steps_by_position! reorders steps with a valid after/before anchor' do
      after_steps = { 'a' => { 'x' => 1 }, 'b' => { 'x' => 2 }, 'c' => { 'position' => { 'after' => 'a' } } }
      before_steps = { 'a' => { 'x' => 1 }, 'b' => { 'x' => 2 }, 'c' => { 'position' => { 'before' => 'a' } } }

      assert_equal ['a', 'c', 'b'], subject.sort_steps_by_position!(after_steps).keys
      assert_equal ['c', 'a', 'b'], subject.sort_steps_by_position!(before_steps).keys
    end

    test 'transform_module_paths maps over array values' do
      result = subject.transform_module_paths('endpoint', ['Foo', 'Bar'], 'DataCycleCore::Generic::Common', 'Import')

      assert_kind_of Array, result
      assert_equal 2, result.size
    end

    test 'other_overrides_pending_in_queue? matches an override with a blank identifier' do
      queue = [{ data: { 'extends' => 'base', 'identifier' => nil } }]

      assert subject.other_overrides_pending_in_queue?('base', queue)
    end

    # --- load_all / validate_all / import_all -----------------------------------------

    test 'validate_all reports no external systems for an empty path' do
      assert_nil subject.validate_all(paths: Pathname.new('/nonexistent/dc-coverage'))
    end

    test 'load_all captures a YAML parse error per file' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'broken.yml'), "name: [unterminated\n")
        errors = subject.load_all(paths: Pathname.new(dir), validation: false)

        assert(errors.any? { |e| e.include?('could not access the YML File') })
      end
    end

    test 'import_all nullifies credentials and imports systems found at a path' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'cov.yml'), { 'name' => 'Cov Import System', 'identifier' => 'cov_import_system' }.to_yaml)
        subject.import_all(paths: Pathname.new(dir), validation: false)

        assert DataCycleCore::ExternalSystem.exists?(identifier: 'cov_import_system')
      end
    end

    # --- embedded validation contracts ------------------------------------------------

    test 'ExternalSystemHeaderContract validates the shape of config.transformations' do
      result = subject::ExternalSystemHeaderContract.new.call(
        {
          name: 'X', identifier: 'x',
          config: { transformations: { a: 'not-an-array', b: ['not-a-hash'], c: [{}] } }
        }
      )
      messages = result.errors.map(&:text)

      assert(messages.any? { |m| m.include?('must be an array of rule hashes') })
      assert(messages.any? { |m| m.include?('must be a hash') })
      assert(messages.any? { |m| m.include?('type must be a non-empty string') })
      assert(messages.any? { |m| m.include?('property must be a non-empty string') })
      assert(messages.any? { |m| m.include?('values must be an array') })
    end

    test 'ExternalSystemStepContract flags a position referencing a missing step' do
      contract = subject::ExternalSystemStepContract.new
      contract.steps = { existing_step: {} }
      result = contract.call({ sorting: 1, position: { before: 'missing_step' } })

      assert(result.errors.map(&:text).any? { |m| m.include?('missing for position') })
    end
  end
end
