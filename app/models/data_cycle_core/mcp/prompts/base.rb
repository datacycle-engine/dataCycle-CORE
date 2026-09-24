# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Prompts
      # Domain base class for MCP prompts -- the counterpart to Tools::Base and Resources::Base (see
      # there). A prompt is the third way a server offers context: not as an instruction to the
      # model (instructions, tool descriptions) but as an entry point the USER picks in the client.
      #
      # The prompts here are deliberately THIN. They do not repeat the procedure stated in the
      # server instructions but point to it and add only what distinguishes this task from any other
      # question. Maintained as a second version of the same manual, the two would drift apart and a
      # client would have two procedure descriptions whose contradiction it cannot resolve -- the
      # same reasoning as in the header of mcp.instructions.
      class Base
        class << self
          attr_accessor :prompt_name, :description_key, :argument_keys

          # Localized prompt description from config/locales/{de,en}.mcp.yml
          # (mcp.prompts.<description_key>.description) -- what appears in the client's selection list.
          def description(locale:)
            t('description', locale)
          end

          # Builds an MCP::Prompt subclass that MCP::Server.new(prompts: [...]) can consume.
          #
          # The arguments are all REQUIRED: a prompt without its input value produces a message with
          # a gap in it, and as an instruction to the model that is worse than an error -- it fills
          # the gap itself.
          def to_mcp_prompt(locale:)
            domain_prompt_class = self

            MCP::Prompt.define(
              name: prompt_name,
              description: description(locale:),
              arguments: Array(argument_keys).map do |key|
                MCP::Prompt::Argument.new(name: key.to_s, description: t("arguments.#{key}", locale), required: true)
              end
            ) do |args, server_context: nil| # rubocop:disable Lint/UnusedBlockArgument -- fixed MCP::Prompt interface
              MCP::Prompt::Result.new(
                description: domain_prompt_class.description(locale:),
                messages: [
                  MCP::Prompt::Message.new(
                    role: 'user',
                    content: MCP::Content::Text.new(domain_prompt_class.message(args.to_h.symbolize_keys, locale:))
                  )
                ]
              )
            end
          end

          # The text that lands in the client as a user message. interpolations are the prompt
          # arguments.
          def message(arguments, locale:)
            t('message', locale, **arguments)
          end

          private

          def t(key, locale, **)
            DataCycleCore::Mcp::Translations.t("prompts.#{description_key}.#{key}", locale:, **)
          end
        end
      end
    end
  end
end
