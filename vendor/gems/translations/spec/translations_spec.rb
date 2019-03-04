# frozen_string_literal: true

require 'spec_helper'

describe Translations do
  it 'has a version number' do
    expect(described_class::VERSION).not_to be nil
  end

  describe 'including Translations in class' do
    let!(:model) do
      model = stub_const 'MyModel', Class.new
      model.class_eval do
        def attributes
          { 'foo' => 'bar' }
        end
      end
      model
    end

    it 'aliases translation_accessor if Translations.config.accessor_method is set' do
      expect(described_class.config).to receive(:accessor_method).and_return(:foo_translates)
      model.extend described_class
      expect { described_class.translates }.to raise_error(NoMethodError)
    end

    it 'does not alias translation_accessor to anything if Translations.config.accessor_method is falsy' do
      expect(described_class.config).to receive(:accessor_method).and_return(nil)
      model.extend described_class
      expect { described_class.translates }.to raise_error(NoMethodError)
    end

    context 'with translated attributes' do
      it 'includes backend module into model class' do
        expect(described_class::Attributes).to receive(:new)
          .with(:title, { method: :accessor, backend: :null, foo: :bar })
          .and_call_original
        model.extend described_class
        model.translates :title, backend: :null, foo: :bar
      end
    end
  end

  describe '.available_locales' do
    around do |example|
      @available_locales = I18n.available_locales
      I18n.available_locales = [:en, :pt]
      example.run
      I18n.available_locales = @available_locales
    end

    it 'defaults to I18n.available_locales' do
      expect(described_class.available_locales).to eq([:en, :pt])
    end

    it 'returns same locales as I18n' do
      expect(described_class.available_locales).to eq(I18n.available_locales)
    end
  end

  describe '.normalize_locale' do
    it 'normalizes locale to lowercase string underscores' do
      expect(described_class.normalize_locale(:'pt-BR')).to eq('pt_br')
    end

    it 'normalizes current locale if passed no argument' do
      I18n.with_locale(:'pt-BR') do
        aggregate_failures do
          expect(described_class.normalize_locale).to eq('pt_br')
          expect(described_class.normalized_locale).to eq('pt_br')
        end
      end
    end

    it 'normalizes locales with multiple dashes' do
      expect(described_class.normalize_locale(:'foo-bar-baz')).to eq('foo_bar_baz')
    end
  end

  describe '.config' do
    it 'initializes a new configuration' do
      expect(described_class.config).to be_a(described_class::Configuration)
    end

    it 'memoizes configuration' do
      expect(described_class.config).to be(described_class.config)
    end
  end

  describe '.configure' do
    it 'yields configuration' do
      expect { |block|
        described_class.configure(&block)
      }.to yield_with_args(described_class.config)
    end
  end
end
