# frozen_string_literal: true

shared_examples_for 'AR Model with serialized translations' do |model_class_name, attribute1 = :title, attribute2 = :content, column_affix: '%s'|
  let(:model_class) { model_class_name.constantize }
  let(:backend) { instance.translation_backends[attribute1.to_sym] }
  let(:column1) { column_affix % attribute1 }
  let(:column2) { column_affix % attribute2 }

  describe '#read' do
    let(:instance) { model_class.new }

    context 'with nil serialized column' do
      it 'returns nil in any locale' do
        expect(backend.read(:en)).to eq(nil)
        expect(backend.read(:ja)).to eq(nil)
      end
    end

    context 'with serialized column' do
      it 'returns translation from serialized hash' do
        instance.send :write_attribute, column1, { ja: 'あああ' }
        instance.save
        instance.reload

        expect(backend.read(:ja)).to eq('あああ')
        expect(backend.read(:en)).to eq(nil)
      end
    end

    context 'multiple serialized columns have translations' do
      it 'returns translation from serialized hash' do
        instance.send :write_attribute, column1, { ja: 'あああ' }
        instance.send :write_attribute, column2, { en: 'aaa' }
        instance.save
        instance.reload

        expect(backend.read(:ja)).to eq('あああ')
        expect(backend.read(:en)).to eq(nil)
        other_backend = instance.translation_backends[attribute2.to_sym]
        expect(other_backend.read(:ja)).to eq(nil)
        expect(other_backend.read(:en)).to eq('aaa')
      end
    end
  end

  describe '#write' do
    let(:instance) { model_class.create }

    it 'assigns to serialized hash' do
      backend.write(:en, 'foo')
      expect(instance.read_attribute(column1)).to match_hash({ en: 'foo' })
      backend.write(:fr, 'bar')
      expect(instance.read_attribute(column1)).to match_hash({ en: 'foo', fr: 'bar' })
    end

    it 'deletes keys with nil values when saving' do
      backend.write(:en, 'foo')
      expect(instance.read_attribute(column1)).to match_hash({ en: 'foo' })
      backend.write(:en, nil)
      expect(instance.read_attribute(column1)).to match_hash({ en: nil })
      instance.save
      expect(backend.read(:en)).to eq(nil)
      expect(instance.read_attribute(column1)).to match_hash({})
    end

    it 'deletes keys with blank values when saving' do
      backend.write(:en, 'foo')
      expect(instance.read_attribute(column1)).to match_hash({ en: 'foo' })
      instance.save
      expect(instance.read_attribute(column1)).to match_hash({ en: 'foo' })
      backend.write(:en, '')
      instance.save

      instance.reload if ENV['RAILS_VERSION'] < '5.0' # don't ask me why
      expect(backend.read(:en)).to eq(nil)

      expect(instance.send(attribute1)).to eq(nil)
      instance.reload
      expect(backend.read(:en)).to eq(nil)
      expect(instance.read_attribute(column1)).to eq({})
    end

    it 'correctly stores serialized attributes' do
      backend.write(:en, 'foo')
      backend.write(:fr, 'bar')
      instance.save
      instance = model_class.first
      backend = instance.translation_backends[attribute1.to_sym]
      expect(instance.send(attribute1)).to eq('foo')
      I18n.with_locale(:fr) { expect(instance.send(attribute1)).to eq('bar') }
      expect(instance.read_attribute(column1)).to match_hash({ en: 'foo', fr: 'bar' })

      backend.write(:en, '')
      instance.save
      instance = model_class.first
      expect(instance.send(attribute1)).to eq(nil)
      expect(instance.read_attribute(column1)).to match_hash({ fr: 'bar' })
    end
  end

  describe 'Model#save' do
    let(:instance) { model_class.new }

    it 'saves empty hash for serialized translations by default' do
      expect(instance.send(attribute1)).to eq(nil)
      expect(backend.read(:en)).to eq(nil)
      instance.save
      expect(instance.read_attribute(column1)).to eq({})
    end

    it 'saves changes to translations' do
      instance.send(:"#{attribute1}=", 'foo')
      instance.save
      instance = model_class.first
      expect(instance.read_attribute(column1)).to match_hash({ en: 'foo' })
    end
  end

  describe 'Model#update' do
    let(:instance) { model_class.create }

    it 'updates changes to translations' do
      instance.send(:"#{attribute1}=", 'foo')
      instance.save
      expect(instance.read_attribute(column1)).to match_hash({ en: 'foo' })
      instance = model_class.first
      instance.update(attribute1 => 'bar')
      expect(instance.read_attribute(column1)).to match_hash({ en: 'bar' })
    end
  end
end
