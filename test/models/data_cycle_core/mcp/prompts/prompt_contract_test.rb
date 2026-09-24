# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Mcp
    module Prompts
      # Assertions for EVERY prompt -- iterated over the registry rather than repeated per prompt,
      # so a newly added one cannot slip past them silently (as in ToolContractTest).
      class PromptContractTest < DataCycleCore::TestCases::ActiveSupportTestCase
        ALL_PROMPTS = (DataCycleCore::Mcp::Servers::Base::PROMPTS + DataCycleCore::Mcp::Servers::Base::WRITE_PROMPTS).freeze
        # See ToolContractTest: every language of the installation, not hard-coded.
        def locales = I18n.available_locales

        test 'every prompt has a name and resolvable texts in every locale' do
          ALL_PROMPTS.each do |prompt|
            assert_predicate prompt.prompt_name, :present?

            locales.each do |locale|
              assert_not_includes prompt.description(locale:), 'translation missing', "#{prompt.prompt_name} (#{locale})"

              arguments = Array(prompt.argument_keys).index_with { |key| "<#{key}>" }
              message = prompt.message(arguments, locale:)

              assert_not_includes message, 'translation missing', "#{prompt.prompt_name}.message (#{locale})"
              arguments.each_value { |value| assert_includes message, value }
            end
          end
        end

        # A prompt argument without a value produces a message with a gap in it -- as an instruction
        # to the model that is worse than an error, since it fills the gap itself.
        test 'every prompt argument is required' do
          ALL_PROMPTS.each do |prompt|
            optional = prompt.to_mcp_prompt(locale: I18n.default_locale).arguments_value.reject(&:required)

            assert_empty optional.map(&:name), prompt.prompt_name
          end
        end

        # The prompts must NOT restate the procedure from the instructions but point to it --
        # otherwise two manuals drift apart whose contradiction a client cannot resolve. The pointer
        # is the checkable form of that agreement.
        test 'every prompt refers to the server instructions instead of restating the procedure' do
          ALL_PROMPTS.each do |prompt|
            arguments = Array(prompt.argument_keys).index_with { |key| "<#{key}>" }

            assert_match(/Server-Instructions/, prompt.message(arguments, locale: :de), prompt.prompt_name)
            assert_match(/server instructions/, prompt.message(arguments, locale: :en), prompt.prompt_name)
          end
        end
      end
    end
  end
end
