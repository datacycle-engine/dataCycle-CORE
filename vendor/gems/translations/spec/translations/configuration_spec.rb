# frozen_string_literal: true

require 'spec_helper'

describe Translations::Configuration do
  subject { Translations::Configuration.new }

  it 'sets default_backend to nil' do
    expect(subject.default_backend).to eq(nil)
  end

  describe '.default_options' do
    it 'raises exception when reserved option keys are set' do
      aggregate_failures do
        [:backend, :model_class].each do |reserved_key|
          expect {
            subject.default_options[reserved_key] = 'value'
          }.to raise_error(Translations::Configuration::ReservedOptionKey)
        end
      end
    end
  end
end
