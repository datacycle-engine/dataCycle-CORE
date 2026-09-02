# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the ThingsByStoredFilter ability segment: it resolves an inline
  # stored-filter definition for the current user (current_user substitution + the
  # `union` shorthand) and reports whether a Thing is contained in the resulting filter.
  class ThingsByStoredFilterSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Abilities::Segments::ThingsByStoredFilter

    before(:all) do
      @user = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
      @tagged = create_content('Artikel', { name: 'tagged article', tags: get_classification_ids('Tags', 'Tag 3') })
      @untagged = create_content('Artikel', { name: 'untagged article' })
    end

    def with_ability(segment, user = @user)
      ability = Object.new
      ability.define_singleton_method(:user) { user }
      segment.ability = ability
      segment
    end

    test 'subject is Thing' do
      assert_equal DataCycleCore::Thing, Subject.new([]).subject
    end

    test 'include? and to_proc are false for a blank definition' do
      segment = with_ability(Subject.new(nil))

      assert_not segment.include?(@tagged)
      assert_not segment.to_proc.call(@tagged)
    end

    test 'include? matches content selected by the resolved stored-filter definition' do
      definition = [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Tags', 'aliases' => ['Tag 3'] } }]
      segment = with_ability(Subject.new(definition))

      assert_includes segment, @tagged
      assert_not segment.include?(@untagged)
    end

    test 'include? resolves union members and substitutes current_user' do
      definition = [{ 'union' => { 'name' => 'scope', 'stored_filter' => [
        { 'shared_with' => 'current_user' },
        { 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Tags', 'aliases' => ['Tag 3'] } }
      ] } }]
      segment = with_ability(Subject.new(definition))

      assert_includes segment, @tagged
      assert_not segment.include?(@untagged)
    end

    test 'resolved_parameters substitutes the current_user placeholder' do
      segment = with_ability(Subject.new([{ 'shared_with' => 'current_user' }]))

      assert_equal @user.id, segment.send(:resolved_parameters).first['v']
    end
  end
end
