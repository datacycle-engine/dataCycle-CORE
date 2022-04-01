# frozen_string_literal: true

# Basic test of translated attribute accessors which can be applied to any backend
shared_examples_for 'model with translated attribute accessors' do |model_class_name, attribute1 = :title, attribute2 = :content, **_options|
  let(:model_class) { constantize(model_class_name) }
  let(:instance) { model_class.new }

  it 'gets and sets translations in one locale' do
    aggregate_failures 'before saving' do
      instance.public_send(:"#{attribute1}=", 'foo')
      expect(instance.public_send(attribute1)).to eq('foo')

      instance.public_send(:"#{attribute2}=", 'bar')
      expect(instance.public_send(attribute2)).to eq('bar')

      instance.save
    end

    aggregate_failures 'after reload' do
      instance = model_class.first

      expect(instance.public_send(attribute1)).to eq('foo')
      expect(instance.public_send(attribute2)).to eq('bar')
    end
  end

  it 'gets and sets translations in multiple locales' do
    aggregate_failures 'before saving' do
      instance.public_send(:"#{attribute1}=", 'foo')
      instance.public_send(:"#{attribute2}=", 'bar')
      I18n.with_locale(:ja) do
        instance.public_send(:"#{attribute1}=", 'あああ')
      end

      expect(instance.public_send(attribute1)).to eq('foo')
      expect(instance.public_send(attribute2)).to eq('bar')
      I18n.with_locale(:ja) do
        expect(instance.public_send(attribute1)).to eq('あああ')
        expect(instance.public_send(attribute2)).to eq(nil)
        expect(instance.public_send(attribute1, { locale: :en })).to eq('foo')
        expect(instance.public_send(attribute2, { locale: :en })).to eq('bar')
      end
      expect(instance.public_send(attribute1, { locale: :ja })).to eq('あああ')
    end

    instance.save
    instance = model_class.first

    aggregate_failures 'after reload' do
      expect(instance.public_send(attribute1)).to eq('foo')
      expect(instance.public_send(attribute2)).to eq('bar')

      I18n.with_locale(:ja) do
        expect(instance.public_send(attribute1)).to eq('あああ')
        expect(instance.public_send(attribute2)).to eq(nil)
      end
    end
  end

  it 'sets translations in multiple locales when creating and saving model' do
    aggregate_failures do
      instance = model_class.create(attribute1 => 'foo', attribute2 => 'bar')

      expect(instance.send(attribute1)).to eq('foo')
      expect(instance.send(attribute2)).to eq('bar')

      I18n.with_locale(:ja) { instance.send("#{attribute1}=", 'あああ') }
      instance.save

      instance = model_class.first

      expect(instance.send(attribute1)).to eq('foo')
      I18n.with_locale(:ja) { expect(instance.send(attribute1)).to eq('あああ') }
      I18n.with_locale(:ja) { expect(instance.send(attribute2)).to eq(nil) }
    end
  end

  it 'sets translations in multiple locales when updating model' do
    instance = model_class.create

    aggregate_failures 'setting attributes with update' do
      instance.update(attribute1 => 'foo')
      expect(instance.send(attribute1)).to eq('foo')
      I18n.with_locale(:ja) do
        instance.update(attribute1 => 'あああ')
        expect(instance.send(attribute1)).to eq('あああ')
      end
    end

    instance = model_class.first

    aggregate_failures 'reading attributes from db after update' do
      expect(instance.send(attribute1)).to eq('foo')
      I18n.with_locale(:ja) { expect(instance.send(attribute1)).to eq('あああ') }
    end
  end
end
