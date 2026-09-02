# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class AdditionalMenuLinkByKeysSegmentTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Abilities::Segments::AdditionalMenuLinkByKeys

    def link(key)
      DataCycleCore::AdditionalMenuLink.new(key, "https://#{key}.example.com/", 'table', nil)
    end

    def with_ability(segment, locale = nil)
      user = Object.new
      user.define_singleton_method(:ui_locale) { locale }
      ability = Object.new
      ability.define_singleton_method(:user) { locale.nil? ? nil : user }
      segment.ability = ability
      segment
    end

    test 'include? matches only the listed keys' do
      segment = Subject.new('grist', :typo3)

      assert_includes segment, link('grist')
      assert_includes segment, link('typo3')
      assert_not segment.include?(link('grafana'))
    end

    test 'all permits every link' do
      segment = Subject.new('all')

      assert_includes segment, link('anything')
    end

    test 'include? rejects other subjects' do
      segment = Subject.new('all')

      assert_not segment.include?(:grist)
      assert_not segment.include?(nil)
    end

    test 'subject is AdditionalMenuLink and to_restrictions renders the keys' do
      segment = with_ability(Subject.new('grist', 'typo3'))

      assert_equal DataCycleCore::AdditionalMenuLink, segment.subject
      assert_equal 'Links: grist, typo3', segment.send(:to_restrictions)
    end

    test 'to_descriptions translates the subject name per locale' do
      descriptions = [:de, :en].map { |locale| with_ability(Subject.new('all'), locale).to_descriptions.first }

      assert_equal I18n.t('activerecord.models.data_cycle_core/additional_menu_link', locale: :de, count: 2), descriptions.first[:permission]
      assert_equal 'Links: all', descriptions.first[:restrictions]
      assert_not_equal descriptions.first[:permission], descriptions.last[:permission]
    end
  end
end
