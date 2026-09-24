# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Mcp
    # Unit tests for the selection and order of the instruction blocks. The text itself is editorial
    # and is not asserted here -- what is checked is that the right block is chosen for the mount,
    # the write permission and the language, because a wrong choice is not visible in the finished
    # text: it reads plausibly in every variant.
    class ServerInstructionsTest < DataCycleCore::TestCases::ActiveSupportTestCase
      ENDPOINT_NAME = 'server instructions test endpoint'

      test 'the endpoint variant names the endpoint, the global variant states the instance-wide scope' do
        endpoint = build(endpoint_name: ENDPOINT_NAME)
        global = build

        assert_includes endpoint, ENDPOINT_NAME
        assert_includes endpoint, translated('endpoint', endpoint_name: ENDPOINT_NAME)
        assert_not_includes endpoint, translated('global')

        assert_includes global, translated('global')
        assert_not_includes global, ENDPOINT_NAME
      end

      # Procedure, language and reporting duty hold regardless of the mount. Maintained as two full
      # texts, they are exactly the parts that would drift apart.
      test 'both variants carry the shared workflow, language and reporting parts' do
        [build, build(endpoint_name: ENDPOINT_NAME)].each do |text|
          DataCycleCore::Mcp::ServerInstructions::SHARED_KEYS.each do |key|
            assert_includes text, translated(key)
          end
        end
      end

      test 'read_only is the default and write_enabled replaces it instead of being added' do
        read_only = build
        writable = build(write_enabled: true)

        assert_includes read_only, translated('read_only')
        assert_not_includes read_only, translated('write_enabled')

        assert_includes writable, translated('write_enabled')
        assert_not_includes writable, translated('read_only')
      end

      test 'the text follows the requested locale and never leaks a missing translation' do
        I18n.available_locales.each do |locale|
          text = build(locale:, endpoint_name: ENDPOINT_NAME, write_enabled: true)

          assert_not_includes text, 'translation missing'
          assert_includes text, translated('workflow', locale:)
        end

        assert_not_equal build(locale: :de), build(locale: :en)
      end

      # The session language is in the text so a client need not guess which language a tool without
      # a locale argument works in -- and which one it writes in.
      test 'the language part names the session locale and the available ones' do
        text = build(locale: :en)

        assert_includes text, 'en'
        I18n.available_locales.each { |locale| assert_includes text, locale.to_s }
      end

      # A client that truncates the text must not lose the result space first: without it, it takes
      # an endpoint subset for the whole inventory and reports "does not exist" where "not in this
      # endpoint" would be right.
      test 'the result space comes first' do
        assert build(endpoint_name: ENDPOINT_NAME).start_with?(translated('endpoint', endpoint_name: ENDPOINT_NAME))
        assert build.start_with?(translated('global'))
      end

      # The reason no measured values stand here (see the class comment): instructions is collected
      # in the MCP::Server constructor and that runs on EVERY request, yet the field is read only by
      # initialize/discover. A count here would be a query on every tools/call.
      test 'building the instructions runs no database query' do
        queries = []
        subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |_, _, _, _, payload|
          queries << payload[:sql] unless payload[:name].in?(['SCHEMA', 'TRANSACTION'])
        end

        build(endpoint_name: ENDPOINT_NAME, write_enabled: true)

        assert_empty queries
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end

      # The channel through which an installation contributes statements of its own without their
      # having to sit in the gem ("gastronomy is modelled here as TouristAttraction plus category").
      # Without it, such knowledge had only one place: the shipped tool descriptions -- and it thereby
      # held as a silent false assumption for every other installation.
      test 'configured instance notes are appended, in the requested language' do
        with_instance_notes({ 'de' => 'Deutscher Hinweis.', 'en' => 'English note.' }) do
          assert build(locale: :de).end_with?('Deutscher Hinweis.')
          assert build(locale: :en).end_with?('English note.')
        end
      end

      # A note maintained in only one language must not be silently missing for a client of the other
      # language -- better in the wrong language than not at all.
      test 'instance notes fall back to the default locale when the requested one is unmaintained' do
        with_instance_notes({ I18n.default_locale.to_s => 'Nur eine Sprache gepflegt.' }) do
          I18n.available_locales.each { |locale| assert_includes build(locale:), 'Nur eine Sprache gepflegt.' }
        end
      end

      test 'a plain string applies to every language and no configuration changes nothing' do
        with_instance_notes('Für alle Sprachen.') do
          I18n.available_locales.each { |locale| assert_includes build(locale:), 'Für alle Sprachen.' }
        end

        with_instance_notes({}) do
          assert build.end_with?(translated('read_only')), 'without configuration the text ends with the write-permission block'
        end
      end

      private

      # Feature::Mcp memoizes its configuration, so the stub needs a reload inside the stubbed
      # window and another one afterwards, or the notes survive into the next test.
      def with_instance_notes(notes)
        features = DataCycleCore.features.deep_dup
        features['mcp']['instance_notes'] = notes

        DataCycleCore.stub(:features, features) do
          DataCycleCore::Feature::Mcp.reload
          yield
        end
      ensure
        DataCycleCore::Feature::Mcp.reload
      end

      def build(locale: I18n.default_locale, write_enabled: false, endpoint_name: nil)
        DataCycleCore::Mcp::ServerInstructions.new(locale:, write_enabled:, endpoint_name:).call
      end

      def translated(key, locale: I18n.default_locale, **)
        DataCycleCore::Mcp::Translations.t(
          "instructions.#{key}",
          locale:,
          session_locale: locale,
          available_locales: I18n.available_locales.join(', '),
          **
        )
      end
    end
  end
end
