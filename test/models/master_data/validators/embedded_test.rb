# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Validators::Embedded do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Validators::Embedded
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Bilder',
        'type' => 'embedded',
        'template_name' => 'Bild',
        'validations' => {
          'max' => 1
        }
      }
    end

    let(:template_class_hash) do
      {
        'label' => 'Geplante Publikation',
        'type' => 'embedded',
        'template_name' => 'Publikations-Plan',
        'validations' => {
          'classifications' => 'no_conflicts'
        }
      }
    end

    let(:multi_template_hash) do
      {
        'label' => 'Embedded Creative-Work',
        'type' => 'embedded',
        'template_name' => ['Embedded-Multiple-Templates-1', 'Embedded-Multiple-Templates-2']
      }
    end

    let(:no_error_hash) do
      { error: {}, warning: {} }
    end

    let(:bild1) do
      DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Bild1' })
    end

    let(:bild2) do
      DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Bild2' })
    end

    # Embedded content cannot be created on its own, so it is reached through a host entity.
    let(:multi_template_embedded_pair) do
      DataCycleCore::TestPreparations.create_content(
        template_name: 'Embedded-Multiple-Templates-Entity-1',
        data_hash: {
          name: 'MultiTemplateHost',
          embedded_creative_work: [
            { name: 'MultiTemplateEmbedded1', template_name: 'Embedded-Multiple-Templates-1' },
            { name: 'MultiTemplateEmbedded2', template_name: 'Embedded-Multiple-Templates-2' }
          ]
        }
      ).embedded_creative_work.to_a
    end

    let(:multi_template_embedded) do
      multi_template_embedded_pair.first
    end

    after do
      DataCycleCore::Thing.where_translated_value(name: 'Bild1').find_by(template_name: 'Bild')&.destroy
      DataCycleCore::Thing.where_translated_value(name: 'Bild2').find_by(template_name: 'Bild')&.destroy
    end

    it 'successfully validates embedded Bild' do
      uuid = bild1.id
      validator = subject.new([{ 'id' => uuid }], template_hash, 'Bilder')

      assert_equal(0, validator.error[:error].size)
    end

    # A slot allowing several templates resolves the item's template from its datahash. An item
    # that is only a reference carries none -- the referenced content answers instead, so it must
    # exist and hold an allowed template (APIv4 push builds exactly this shape once the embedded
    # content has been written).
    it 'accepts a reference to embedded content of an allowed template' do
      validator = subject.new([{ 'id' => multi_template_embedded.id }], multi_template_hash, 'embedded_creative_work')

      assert_equal(0, validator.error[:error].size)
    end

    # Ids come back from the lookup in the spelling Postgres stores them in, so a reference
    # written in another one has to be normalised before it can be matched against them.
    it 'accepts a reference whose id is spelled differently than it is stored' do
      [multi_template_embedded.id.upcase, "{#{multi_template_embedded.id}}"].each do |id|
        validator = subject.new([{ 'id' => id }], multi_template_hash, 'embedded_creative_work')

        assert_equal(0, validator.error[:error].size, "id: #{id.inspect}")
      end
    end

    # Counts the queries a block triggers, ignoring schema lookups and query-cache hits.
    def count_queries(&)
      count = 0
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |_, _, _, _, payload|
        count += 1 unless payload[:name] == 'SCHEMA' || payload[:cached]
      end

      DataCycleCore::Thing.uncached(&)

      count
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    # APIv4 reduces every embedded item to a bare id and validation re-runs once per pushed
    # locale, so resolving one reference per query would cost items x locales lookups on exactly
    # the path these references arrive on.
    it 'does not spend a query per reference' do
      first, second = multi_template_embedded_pair
      # warm up: template and configuration lookups are memoized per process, so a cold first
      # call would carry queries the second no longer pays for
      subject.new([{ 'id' => first.id }], multi_template_hash, 'embedded_creative_work')

      one = count_queries { subject.new([{ 'id' => first.id }], multi_template_hash, 'embedded_creative_work') }
      two = count_queries { subject.new([{ 'id' => first.id }, { 'id' => second.id }], multi_template_hash, 'embedded_creative_work') }

      assert_operator two, :<=, one, "#{two - one} additional queries for one additional reference"
    end

    it 'rejects a reference to content the slot does not allow' do
      assert_raises(DataCycleCore::Error::TemplateNotAllowedError) do
        subject.new([{ 'id' => bild1.id }], multi_template_hash, 'embedded_creative_work')
      end
    end

    it 'rejects a reference to content that does not exist' do
      assert_raises(DataCycleCore::Error::TemplateNotAllowedError) do
        subject.new([{ 'id' => SecureRandom.uuid }], multi_template_hash, 'embedded_creative_work')
      end
    end

    it 'rejects a reference without an id' do
      [nil, ''].each do |blank_id|
        assert_raises(DataCycleCore::Error::TemplateNotAllowedError, "blank id: #{blank_id.inspect}") do
          subject.new([{ 'id' => blank_id }], multi_template_hash, 'embedded_creative_work')
        end
      end
    end

    it 'rejects a reference whose id is not a single uuid' do
      [[multi_template_embedded.id], 42, { 'id' => multi_template_embedded.id }].each do |odd_id|
        assert_raises(DataCycleCore::Error::TemplateNotAllowedError, "id: #{odd_id.inspect}") do
          subject.new([{ 'id' => odd_id }], multi_template_hash, 'embedded_creative_work')
        end
      end
    end

    # The reference check runs before the template is resolved, so it short-circuits
    # single-template slots as well. Whatever it does not recognise has to fall back to
    # validating the item, which is where a malformed id is caught.
    it 'still validates an id a single-template slot cannot resolve' do
      validator = subject.new([{ 'id' => 'not-a-uuid' }], template_hash, 'Bilder')

      assert_equal(1, validator.error[:error].size)
    end

    it 'still demands a template_name when the item carries a datahash' do
      item = [{ 'id' => multi_template_embedded.id, 'datahash' => { 'name' => 'Ohne Template' } }]

      assert_raises(DataCycleCore::Error::TemplateNotAllowedError) do
        subject.new(item, multi_template_hash, 'embedded_creative_work')
      end
    end

    it 'produces no error if a wrong validations keyword is given' do
      new_template_hash = template_hash.deep_dup
      new_template_hash['validations'] = { 'maxi' => 2 }
      item_case = [{ 'id' => SecureRandom.uuid }]
      validator = subject.new(item_case, new_template_hash)

      assert_equal(0, validator.error[:error].size)
    end

    it 'produces an error if a wrong template_name is given' do
      new_template_hash = template_hash.deep_dup
      new_template_hash['template_name'] = 'maxi'
      item_case = [{ 'id' => SecureRandom.uuid }]
      validator = subject.new(item_case, new_template_hash)

      assert_equal(1, validator.error[:error].size)
    end

    it 'successfully validates more than one embedded item' do
      new_template_hash = template_hash.deep_dup.except('validations')
      uuid = bild1.id
      uuid2 = bild2.id
      data_cases = [
        { 'id' => uuid },
        [{ 'id' => uuid }],
        [{ 'id' => uuid }, { 'id' => uuid2 }]
      ]
      data_cases.each do |item_case|
        validator = subject.new(item_case, new_template_hash)

        assert_equal(0, validator.error[:error].size)
      end
    end

    it 'produces an error if max is exceeded' do
      new_template_hash = template_hash.deep_dup
      uuid = bild1.id
      uuid2 = bild2.id
      item_case = [{ 'id' => uuid }, { 'id' => uuid2 }]
      validator = subject.new(item_case, new_template_hash)

      assert_equal(1, validator.error[:error].size)
    end

    it 'produces an error if min is not reached' do
      new_template_hash = template_hash.deep_dup
      new_template_hash['validations'] = { 'min' => 2 }
      uuid = bild1.id
      item_case = [{ 'id' => uuid }]
      validator = subject.new(item_case, new_template_hash)

      assert_equal(1, validator.error[:error].size)
    end

    it 'rejects data in the following formats' do
      new_template_hash = template_hash.deep_dup.except('validations')
      uuid = bild1.id
      uuid2 = bild2.id
      data_cases = [
        uuid,
        [uuid],
        [uuid, uuid2],
        [{ 'id' => uuid }, uuid2]
      ]
      data_cases.each do |item_case|
        validator = subject.new(item_case, new_template_hash)

        assert_equal(1, validator.error[:error].size)
      end
    end

    it 'validates properly classification_conflicts for a single classification' do
      old_class = DataCycleCore.features[:publication_schedule][:classification_keys]
      DataCycleCore.features[:publication_schedule][:classification_keys] = ['output_channel']

      output_channel1 = DataCycleCore::Classification.where(name: 'Web').first.id
      output_channel2 = DataCycleCore::Classification.where(name: 'Social Media').first.id

      data_hash1 = [
        { 'output_channel' => [output_channel1] },
        { 'output_channel' => [output_channel2] }
      ]
      validator = subject.new(data_hash1, template_class_hash)

      assert_equal(0, validator.error[:error].size)

      data_hash2 = [
        { 'output_channel' => [output_channel1] },
        { 'output_channel' => [output_channel1, output_channel2] }
      ]
      validator = subject.new(data_hash2, template_class_hash)

      assert_equal(1, validator.error[:error].size)

      DataCycleCore.features[:publication_schedule][:classification_keys] = old_class
    end

    it 'validates properly classification_conflicts for multiple classifications' do
      old_class = DataCycleCore.features[:publication_schedule][:classification_keys]
      DataCycleCore.features[:publication_schedule][:classification_keys] = ['output_channel', 'markets']

      market1 = DataCycleCore::Classification.where(name: 'Markt 1').first.id
      market2 = DataCycleCore::Classification.where(name: 'Markt 2').first.id

      output_channel1 = DataCycleCore::Classification.where(name: 'Web').first.id
      output_channel2 = DataCycleCore::Classification.where(name: 'Social Media').first.id

      data_hash1 = [
        { 'markets' => [market2], 'output_channel' => [output_channel1] },
        { 'markets' => [market1], 'output_channel' => [output_channel2] }
      ]
      validator = subject.new(data_hash1, template_class_hash)

      assert_equal(0, validator.error[:error].size)

      data_hash2 = [
        { 'markets' => [market1, market2], 'output_channel' => [output_channel1] },
        { 'markets' => [market2], 'output_channel' => [output_channel2] }
      ]
      validator = subject.new(data_hash2, template_class_hash)

      assert_equal(0, validator.error[:error].size)

      data_hash3 = [
        { 'markets' => [market1, market2], 'output_channel' => [output_channel1] },
        { 'markets' => [market2], 'output_channel' => [output_channel1, output_channel2] }
      ]
      validator = subject.new(data_hash3, template_class_hash)

      assert_equal(1, validator.error[:error].size)

      DataCycleCore.features[:publication_schedule][:classification_keys] = old_class
    end
  end
end
