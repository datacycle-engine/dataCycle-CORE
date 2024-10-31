# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::Schema do
  include DataCycleCore::MinitestSpecHelper

  subject do
    template_importer = DataCycleCore::MasterData::Templates::TemplateImporter.new(
      template_paths: [Rails.root.join('..', 'data_types', 'simple_valid_templates')]
    )
    cw = template_importer.templates[:creative_works]
    DataCycleCore::Schema.new(
      [
        DataCycleCore::Schema::Template.new(cw.find { |t| t[:name] == 'Container One' }[:data].as_json),
        DataCycleCore::Schema::Template.new(cw.find { |t| t[:name] == 'Container Two' }[:data].as_json),
        DataCycleCore::Schema::Template.new(cw.find { |t| t[:name] == 'Container Three' }[:data].as_json),
        DataCycleCore::Schema::Template.new(cw.find { |t| t[:name] == 'Entity One' }[:data].as_json),
        DataCycleCore::Schema::Template.new(cw.find { |t| t[:name] == 'Entity Two' }[:data].as_json),
        DataCycleCore::Schema::Template.new(cw.find { |t| t[:name] == 'Entity Three' }[:data].as_json),
        DataCycleCore::Schema::Template.new(cw.find { |t| t[:name] == 'Entity Four' }[:data].as_json)
      ]
    )
  end

  it 'should should provide list of available content types' do
    assert_equal(['container', 'entity'], subject.content_types.sort)
  end

  it 'should should provide list of container templates' do
    assert_equal([['ContainerOne'], ['ContainerTwo'], ['ContainerThree']].sort, subject.templates_with_content_type('container').map(&:schema_name).sort)
  end

  it 'should should provide list of entity templates' do
    assert_equal([['EntityOne'], ['EntityTwo'], ['EntityThree'], ['EntityFour']].sort, subject.templates_with_content_type('entity').map(&:schema_name).sort)
  end
end
