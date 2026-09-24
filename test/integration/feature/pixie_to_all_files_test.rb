# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # The callout the upload mask's "apply this pixie to every file" button shows when the service
  # answered with nothing for some of the other files (#47879, #47881).
  #
  # The file being edited says so in its own form element, through the wand the button clicks. The
  # other files have no form in the dom to say it in, so the run reports once at page level -- and
  # builds that message from the pixie's own wording plus how many files it holds for.
  #
  # There is no javascript suite in this gem, so what is pinned here is the contract the component
  # depends on: GET /i18n/translate answers this key with the pluralisation hash I18n.translate
  # indexes by count, and every placeholder it interpolates is actually in the text.
  class PixieToAllFilesTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    EMPTY_KEY = 'frontend.upload.pixie_to_all_empty'
    # what PIXIES[...].emptyKey names in app/assets/javascripts/helpers/pixies.js, i.e. the message
    # the key above interpolates as %{message}
    PIXIE_EMPTY_KEYS = [
      'frontend.annotation_pixie.no_suggestions',
      'frontend.image_description_pixie.no_suggestion'
    ].freeze
    LOCALES = ['de', 'en'].freeze
    VARIANTS = ['one', 'other'].freeze
    # the placeholders I18n.translate interpolates client side, spelled without the braces rubocop
    # reads as a format token -- these are asserted as literal text, not used to format anything
    PLACEHOLDERS = ['message', 'count'].map { |name| "%{#{name}}" }.freeze

    before(:all) do
      @current_user = User.find_by(email: 'admin@datacycle.at')
    end

    setup do
      sign_in(@current_user)
    end

    # I18n.translate reads text[countMapping(count)] with 'one' and 'other' only when the endpoint
    # hands it an object, so a flat string here would leave the callout showing "[object Object]".
    #
    # Asked once, not once per locale: ApplicationController#translate permits :path alone and
    # answers in helpers.active_ui_locale, so passing a locale asserted the signed in user's
    # language twice over. Every locale is covered below, where I18n is asked directly.
    test 'the endpoint answers the empty callout as a pluralisation hash' do
      get '/i18n/translate', params: { path: EMPTY_KEY }, headers: JSON_HEADERS

      assert_response :success

      text = response.parsed_body['text']

      assert_kind_of ::Hash, text, "expected #{EMPTY_KEY} to be a pluralisation hash"
      assert_equal ['one', 'other'], text.keys.sort
    end

    # The shape the endpoint hands over is only right if it is right in every locale, which the
    # request above cannot see.
    test 'the empty callout is a pluralisation hash in every locale' do
      LOCALES.each do |locale|
        text = I18n.t(EMPTY_KEY, locale:)

        assert_kind_of ::Hash, text, "expected #{EMPTY_KEY} to be a pluralisation hash in #{locale}"
        assert_equal ['one', 'other'], text.keys.map(&:to_s).sort, "expected one and other in #{locale}"
      end
    end

    # Both placeholders are interpolated client side, and the banner names a number of files rather
    # than "the other files", so a variant missing %{count} says "Betrifft Dateien" without saying
    # how many -- including the singular, which reads "Betrifft 1 Datei".
    test 'both variants name the pixie message and the count' do
      LOCALES.each do |locale|
        text = I18n.t(EMPTY_KEY, locale:)

        VARIANTS.each do |variant|
          PLACEHOLDERS.each do |placeholder|
            assert_includes text[variant.to_sym], placeholder, "expected #{placeholder} in #{locale}.#{variant}"
          end
        end
      end
    end

    # The composed message is only as good as the part it quotes: an emptyKey the endpoint 404s on
    # would leave the callout reading the key path back to the user.
    test 'every pixie empty message the callout quotes resolves' do
      PIXIE_EMPTY_KEYS.each do |key|
        get '/i18n/translate', params: { path: key }, headers: JSON_HEADERS

        assert_response :success, "expected #{key} to resolve"

        text = response.parsed_body['text']

        assert_kind_of ::String, text, "expected #{key} to be a plain string"
        assert_predicate text, :present?

        LOCALES.each do |locale|
          assert I18n.exists?(key, locale:), "expected #{key} in #{locale}"
          assert_kind_of ::String, I18n.t(key, locale:), "expected #{key} to be a plain string in #{locale}"
        end
      end
    end
  end
end
