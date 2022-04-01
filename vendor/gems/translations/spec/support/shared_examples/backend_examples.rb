# frozen_string_literal: true

shared_examples_for 'Translations backend' do |backend_class, model_class, attribute = 'title', **options|
  let(:backend) do
    model_class = model_class.constantize if model_class.is_a?(String)

    options = { model_class: model_class, **options }
    klass = backend_class.with_options(options)
    klass.setup_model(model_class, [attribute])
    klass.new(model_class.new, attribute)
  end

  describe 'accessors' do
    it 'can be called without options hash' do
      backend.write(I18n.locale, 'foo')
      backend.read(I18n.locale)
      expect(backend.read(I18n.locale)).to eq('foo')
    end
  end

  describe 'iterators' do
    it 'iterates through locales' do
      backend.write(:en, 'foo')
      backend.write(:ja, 'bar')
      backend.write(:ru, 'baz')

      expect { |b| backend.each_locale(&b) }.to yield_successive_args(:en, :ja, :ru)
      expect { |b| backend.each(&b) }.to yield_successive_args(
        Translations::Backend::Translation.new(backend, :en),
        Translations::Backend::Translation.new(backend, :ja),
        Translations::Backend::Translation.new(backend, :ru)
      )
      expect(backend.locales).to eq([:en, :ja, :ru])
    end
  end
end
