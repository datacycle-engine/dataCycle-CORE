# frozen_string_literal: true

require 'spec_helper'
require 'translations/backend/orm_delegator'

describe Translations::Backend::OrmDelegator do
  before do
    stub_const 'Translations::MyClass', Module.new
    Translations::MyClass.extend described_class
    stub_const 'Translations::ActiveRecord::MyClass', Class.new
  end
  subject { Translations::MyClass }

  context 'No ORM model const defined', orm: :none do
    describe '.for' do
      it 'raises ArgumentError with correct message' do
        expect {
          subject.for(Class.new)
        }.to raise_error(ArgumentError, 'MyClass backend can only be used by ActiveRecord')
      end
    end
  end

  context 'ActiveRecord const defined', orm: :active_record do
    describe '.for' do
      it 'raises ArgumentError with correct message when model does not inherit from ActiveRecord::Base' do
        expect {
          subject.for(Class.new)
        }.to raise_error(ArgumentError, 'MyClass backend can only be used by ActiveRecord')
      end

      it 'returns ActiveRecord::MyClass when model inherits from ActiveRecord' do
        expect(subject.for(Class.new(::ActiveRecord::Base))).to eq(Translations::ActiveRecord::MyClass)
      end
    end
  end
end
