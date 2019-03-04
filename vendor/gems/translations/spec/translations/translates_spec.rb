# frozen_string_literal: true

require 'spec_helper'

describe Translations::Translates do
  before do
    stub_const('MyClass', Class.new).extend(Translations::Translates)
  end
  let(:attribute_names) { [:title, :content] }

  describe '.translation_accessor' do
    it 'includes new Attributes module' do
      attributes = Module.new do
        def self.each(&block)
        end
      end
      expect(Translations::Attributes).to receive(:new).with(*attribute_names, { method: :accessor }).and_return(attributes)
      MyClass.translation_accessor(*attribute_names)
    end

    it 'yields to block with backend as context if block given' do
      attributes = Module.new do
        def self.backend
        end

        def self.each(&block)
        end
      end
      backend = double('backend')
      expect(attributes).to receive(:backend).and_return(backend)
      expect(backend).to receive(:foo).with('bar')
      allow(Translations::Attributes).to receive(:new).and_return(attributes)
      MyClass.translation_accessor :title do
        foo('bar')
      end
    end
  end
end
