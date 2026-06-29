# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Validators::Oembed do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Validators::Oembed
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'oembed',
        'storage_location' => 'value'
      }
    end

    let(:required_template_hash) do
      {
        'label' => 'Test',
        'type' => 'oembed',
        'storage_location' => 'value',
        'validations' => { 'required' => true }
      }
    end

    let(:soft_required_template_hash) do
      {
        'label' => 'Test',
        'type' => 'oembed',
        'storage_location' => 'value',
        'validations' => { 'soft_required' => true }
      }
    end

    let(:url) do
      'https://www.youtube.com/watch?v=AlGcVkVzxt0&t=1s&pp=ygUJZGF0YWN5Y2xl'
    end

    let(:no_error_hash) do
      { error: {}, warning: {}, result: { '' => ["https://www.youtube.com/oembed?url=#{url}"] } }
    end

    it 'error on blank url if validation is required:true' do
      validator = subject.new(nil, required_template_hash)

      assert_equal(1, validator.error[:error].size)
    end

    it 'warning on blank url if validation is soft_required:true' do
      validator = subject.new(nil, soft_required_template_hash)

      assert_equal(1, validator.error[:warning].size)
    end

    it 'no warning/error on blank url if validation is neither soft_required:true nor required:true' do
      validator = subject.new(nil, soft_required_template_hash)

      assert_equal(1, validator.error[:warning].size)
    end

    it 'works with a real values' do
      validator = subject.new(url, template_hash)

      assert_equal(no_error_hash, validator.error)
    end

    it 'error if invalid url' do
      validator = subject.new('ht//www.youtube.com/watch?v=AlGcVkVzxt0&t=1s&pp=ygUJZGF0YWN5Y2xl', template_hash)

      assert_equal(1, validator.error[:error].size)
    end

    it 'error if valid url, but no url provider found' do
      validator = subject.new('http://www.you-tube.com/watch?v=AlGcVkVzxt0&t=1s&pp=ygUJZGF0YWN5Y2xl', template_hash)

      assert_equal(1, validator.error[:error].size)
    end

    it 'parsed_url works with special urls' do
      parsed_url = subject.new(validate_now: false).parsed_url('https://kristberg.at/livebild/bergstation.jpg<img class="NO-CACHE">')

      assert_equal('kristberg.at', parsed_url.host)
      assert_equal('/livebild/bergstation.jpg<img class="NO-CACHE">', parsed_url.path)
      assert_equal('https', parsed_url.scheme)
    end

    it 'runs template validations for a resolvable url' do
      validator = subject.new(validate_now: false)
      provider = { 'oembed_url' => 'https://provider.test/oembed.{format}', 'provider_name' => 'X', 'provider_url' => 'https://provider.test' }

      result = validator.stub(:select_provider, [provider]) do
        validator.validate('https://provider.test/watch?v=1', required_template_hash)
      end

      assert_empty(result[:error])
      assert_predicate(result[:result], :present?)
    end

    it 'adds a warning via soft_required validation' do
      validator = subject.new(validate_now: false)
      provider = { 'oembed_url' => 'https://provider.test/oembed.{format}', 'provider_name' => 'X', 'provider_url' => 'https://provider.test' }

      validator.stub(:select_provider, [provider]) do
        validator.validate('https://provider.test/watch?v=1', soft_required_template_hash)
      end

      assert_empty(validator.error[:error])
    end

    it 'parsed_url returns nil for unparseable urls' do
      validator = subject.new(validate_now: false)

      Addressable::URI.stub(:parse, ->(_data) { raise Addressable::URI::InvalidURIError }) do
        assert_nil(validator.parsed_url('https://example.test'))
      end
    end
  end

  describe 'oembed data resolution' do
    include DataCycleCore::MinitestSpecHelper

    subject { DataCycleCore::MasterData::Validators::Oembed }

    let(:single_provider) do
      { 'oembed_url' => 'https://provider.test/oembed.{format}', 'provider_name' => 'X', 'provider_url' => 'https://provider.test' }
    end

    it 'reports an error for blank data' do
      validator = subject.new(validate_now: false)
      result = validator.valid_oembed_data?('')

      assert_not(result[:success])
      assert_predicate(validator.error[:error], :present?)
    end

    it 'reports an error when no provider matches' do
      validator = subject.new(validate_now: false)
      result = validator.stub(:select_provider, []) do
        validator.valid_oembed_data?('https://nowhere.test/x')
      end

      assert_not(result[:success])
    end

    it 'reports an error when too many providers match' do
      validator = subject.new(validate_now: false)
      providers = [single_provider, single_provider.merge('provider_url' => 'https://other.test')]
      result = validator.stub(:select_provider, providers) do
        validator.valid_oembed_data?('https://provider.test/x')
      end

      assert_not(result[:success])
    end

    it 'builds a dcThingOembed url when the thing exists' do
      thing = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'OEmbed Thing' })
      validator = subject.new(validate_now: false)
      provider = { 'oembed_url' => 'https://provider.test/oembed.{format}?u={dcThingOembed}', 'provider_name' => 'X', 'provider_url' => 'https://provider.test' }

      result = validator.stub(:select_provider, [provider]) do
        validator.valid_oembed_data?("https://provider.test/things/#{thing.id}")
      end

      assert(result[:success])
      assert_includes(result[:oembed_url], "thing_id=#{thing.id}")
    end

    it 'reports an error for a dcThingOembed url with a missing thing' do
      validator = subject.new(validate_now: false)
      provider = { 'oembed_url' => 'https://provider.test/oembed.{format}?u={dcThingOembed}', 'provider_name' => 'X', 'provider_url' => 'https://provider.test' }

      result = validator.stub(:select_provider, [provider]) do
        validator.valid_oembed_data?('https://provider.test/things/00000000-0000-0000-0000-000000000000')
      end

      assert_not(result[:success])
    end

    it 'providers merges base providers and additional providers' do
      validator = subject.new(validate_now: false)
      base = [{ 'provider_url' => 'https://base.test', 'provider_name' => 'Base' }]
      config = { 'base_json' => 'https://providers.test/list.json', 'oembed_providers' => [{ 'provider_url' => 'https://add.test', 'provider_name' => 'Add' }] }

      DataCycleCore.stub(:oembed_providers, config) do
        Rails.cache.delete('https://providers.test/list.json')
        Net::HTTP.stub(:get, base.to_json) do
          result = validator.providers

          assert(result.key?('https://base.test'))
          assert(result.key?('https://add.test'))
        end
      end
    end

    it 'from_url extracts image dimensions' do
      validator = subject.new(validate_now: false)

      FastImage.stub(:size, [640, 480]) do
        assert_equal(480, validator.from_url('https://img.test/x.jpg', 'height'))
        assert_equal(640, validator.from_url('https://img.test/x.jpg', 'width'))
      end
      FastImage.stub(:size, nil) do
        assert_nil(validator.from_url('https://img.test/x.jpg', 'height'))
      end
    end

    it 'valid_oembed_from_thing_id rescues a missing thing' do
      validator = subject.new(validate_now: false)
      missing_id = '00000000-0000-0000-0000-000000000000'
      result = validator.valid_oembed_from_thing_id(missing_id)

      assert_not(result[:success])
      assert_equal(missing_id, result[:requested_thing_id])
    end

    it 'valid_oembed_from_thing_id reports thing-not-found when no output template matches' do
      thing = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'No Match' })
      validator = subject.new(validate_now: false)
      provider = { 'output' => [{ 'template_names' => ['SomethingElse'], 'type' => 'rich', 'version' => '1.0' }] }.with_indifferent_access

      result = validator.stub(:select_provider, ->(arg) { arg.to_s.include?('/things/') ? [provider] : [] }) do
        validator.valid_oembed_from_thing_id(thing.id)
      end

      assert_not(result[:success])
    end

    it 'valid_oembed_from_thing_id builds oembed output for a matching provider' do
      thing = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'OEmbed Article' })
      validator = subject.new(validate_now: false)
      provider = {
        'provider_name' => 'dataCycle',
        'output' => [{
          'template_names' => [thing.template_name],
          'type' => 'rich',
          'version' => '1.0',
          'url' => '{name}',
          'html' => '<div>{name}</div>',
          'width' => '{val:640}',
          'height' => '{val:480}',
          'override_provider' => []
        }]
      }.with_indifferent_access

      result = validator.stub(:select_provider, ->(arg) { arg.to_s.include?('/things/') ? [provider] : [] }) do
        validator.valid_oembed_from_thing_id(thing.id)
      end

      assert(result[:success])
      assert_equal('<div>OEmbed Article</div>', result[:oembed][:html])
      assert_equal(640, result[:oembed][:width])
    end

    it 'valid_oembed_from_thing_id uses the external source provider and resolves {url} provider_url' do
      thing = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'External Source Article' })
      thing.external_source_id = DataCycleCore::ExternalSystem.first.id
      thing.save!
      validator = subject.new(validate_now: false)
      provider = {
        'output' => [{
          'template_names' => [thing.template_name],
          'type' => 'rich', 'version' => '1.0',
          'url' => '{name}', 'html' => '<div>{name}</div>',
          'override_provider' => []
        }]
      }.with_indifferent_access

      result = validator.stub(:select_provider, ->(arg) { arg.to_s.include?('/things/') ? [provider] : [] }) do
        validator.valid_oembed_from_thing_id(thing.id)
      end

      assert(result[:success])
      assert_equal(thing.external_source.name, result[:oembed][:provider_name])
    end

    it 'valid_oembed_from_thing_id fetches third-party oembed data over http' do
      thing = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Webcam Article' })
      validator = subject.new(validate_now: false)
      provider = {
        'oembed_url' => 'https://provider.test/oembed.{format}',
        'output' => [{
          'template_names' => [thing.template_name],
          'type' => 'rich', 'version' => '1.0',
          'url' => '{name}', 'override_provider' => []
        }]
      }.with_indifferent_access

      response = Net::HTTPOK.new('1.1', '200', 'OK')
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, '{"type":"video","html":"<iframe></iframe>"}')

      result = validator.stub(:select_provider, [provider]) do
        Net::HTTP.stub(:get_response, response) do
          validator.valid_oembed_from_thing_id(thing.id)
        end
      end

      assert_equal('video', result[:oembed]['type'])
    end

    it 'providers returns additional providers when the base fetch fails' do
      validator = subject.new(validate_now: false)
      config = { 'base_json' => 'https://providers.test/fail.json', 'oembed_providers' => [{ 'provider_url' => 'https://add.test', 'provider_name' => 'Add' }] }

      DataCycleCore.stub(:oembed_providers, config) do
        Rails.cache.delete('https://providers.test/fail.json')
        Net::HTTP.stub(:get, ->(_url) { raise StandardError, 'boom' }) do
          result = validator.providers

          assert(result.key?('https://add.test'))
        end
      end
    end

    it 'valid_oembed_from_thing_id applies a matching override_provider' do
      validator = subject.new(validate_now: false)
      thing = Struct.new(:template_name, :url, :name, :external_source).new('Artikel', 'https://match.example/things/1', 'Doubled', nil)
      provider = {
        'output' => [{
          'template_names' => ['Artikel'],
          'type' => 'rich', 'version' => '1.0',
          'url' => '{name}', 'html' => '<div>{name}</div>',
          'override_provider' => [{ 'host_match' => 'match.example', 'provider_name' => 'Override', 'provider_url' => 'https://override.test' }]
        }]
      }.with_indifferent_access

      result = DataCycleCore::Thing.stub(:find, thing) do
        validator.stub(:select_provider, ->(arg) { arg.to_s.include?('/things/') ? [provider] : [] }) do
          validator.valid_oembed_from_thing_id('11111111-1111-1111-1111-111111111111')
        end
      end

      assert(result[:success])
      assert_equal('Override', result[:oembed][:provider_name])
      assert_equal('https://override.test', result[:oembed][:provider_url])
    end
  end
end
