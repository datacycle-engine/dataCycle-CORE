# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    # Stage resolution of the life-cycle feature: #archive_name/#archive_id have had a counterpart
    # for the active side since #37010, so callers (import steps, cleanup rake tasks) no longer carry
    # their own hardcoded stage name.
    class LifeCycleStagesTest < DataCycleCore::TestCases::ActiveSupportTestCase
      SUBJECT = DataCycleCore::Feature::LifeCycle

      # a content per test, not per class: the stage of a shared one is memoized on the object
      # (Feature::Content::LifeCycle#life_cycle_stage) and would survive the transaction rollback
      # between tests, so a later test would read the stage an earlier one set
      setup do
        @content = DataCycleCore::TestPreparations.create_content(
          template_name: 'Artikel', data_hash: { 'name' => 'life-cycle-stages' }
        )
      end

      def move_to_stage(name)
        @content.set_life_cycle_classification(SUBJECT.ordered_classifications(@content)&.dig(name, :id), nil)
      end

      # merges into the real configuration instead of replacing it: `ordered` and `tree_label` still
      # have to resolve, they are what ordered_classifications keys on
      def with_active_name(name, &)
        configuration = SUBJECT.configuration(@content).merge('active_name' => name)

        SUBJECT.stub(:configuration, ->(*) { configuration }, &)
      end

      test 'active_name falls back to the DataCycle-wide default' do
        assert_equal SUBJECT::DEFAULT_ACTIVE_NAME, SUBJECT.active_name(@content)
      end

      test 'active_name prefers the configured stage over the default' do
        with_active_name('Aktuelle Inhalte') do
          assert_equal 'Aktuelle Inhalte', SUBJECT.active_name(@content)
        end
      end

      test 'active_name lets a caller override the configuration' do
        with_active_name('Aktuelle Inhalte') do
          assert_equal 'Recherche', SUBJECT.active_name(@content, 'Recherche')
        end
      end

      test 'active_id resolves the stage against the content life cycle' do
        expected = SUBJECT.ordered_classifications(@content)&.dig('Aktuelle Inhalte', :id)

        assert_equal expected, SUBJECT.active_id(@content, 'Aktuelle Inhalte')
      end

      test 'active_id is nil for a stage the content does not have' do
        assert_nil SUBJECT.active_id(@content, 'Nicht konfigurierte Stufe')
      end

      test 'reactivate moves the content to the named stage' do
        # the template defaults to "Aktuelle Inhalte", so move it away first - otherwise the
        # transition is a no-op and proves nothing
        move_to_stage('Vorschläge')

        assert @content.reactivate(nil, stage_name: 'Aktuelle Inhalte')
        assert @content.reload.life_cycle_stage_name?('Aktuelle Inhalte')
      end

      test 'reactivate uses the configured active stage when the caller names none' do
        with_active_name('Recherche') do
          assert @content.reactivate
        end

        assert @content.reload.life_cycle_stage_name?('Recherche')
      end

      test 'reactivate leaves the content alone when the stage is not configured' do
        assert_not @content.reactivate(nil, stage_name: 'Nicht konfigurierte Stufe')
      end
    end
  end
end
