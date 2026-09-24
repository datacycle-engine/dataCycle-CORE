# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # The write path behind the create_content/update_content tools -- the same route as
    # ContentsController#create/#update (DataHashService.create_internal_object and
    # Content#set_data_hash_with_translations), plus the three things an MCP client additionally
    # needs:
    #
    # 1. Splitting a FLAT attribute hash into the {translations:, datahash:} shape. An MCP client
    #    cannot know which attribute is translatable; and a flat hash handed straight to
    #    create_internal_object also lands in Thing.new(...) there (new_params =
    #    object_params.except(:translations, :datahash)) and thereby hits the deprecated setter from
    #    Content#method_missing -- verified in practice, silent in the test env, a NoMethodError in
    #    dev.
    # 2. EXPLICIT feedback about omitted attributes: set_data_hash silently slices away keys the
    #    template does not know (see Content::DataHash#set_data_hash). An LLM otherwise reads that
    #    as "saved" and reports it onwards unchecked. The same holds for an attribute that already
    #    carried its value and is therefore not written -- which is why the response carries
    #    changed_attributes beside applied_attributes.
    # 3. An error instead of a success payload when validation fails: the creation is rolled back in
    #    that case, but the returned object still carries an id. The result is evaluated in the
    #    WRITE LANGUAGE, or it comes up empty (see #with_write_locale).
    #
    # The boundary of authorization is the ability on the content (:create/:update, see
    # TemplateByCreatableScope and ContentIsEditable) plus the attribute whitelist below.
    # Attribute permissions (Ability#can_attribute?) are NOT evaluated -- as with the importer,
    # whose write path uses the same whitelist.
    class ContentWriter
      include DataCycleCore::Mcp::BadRequest

      # A writer for one tool call: the same three values from the arguments and the server context
      # for every writing tool. Without this place, the resolution of the write language (argument
      # before mount language) stands there again per tool and diverges at the next one.
      def self.for(arguments:, context:)
        new(
          current_user: context[:current_user],
          ability: context[:ability],
          locale: arguments[:locale] || context[:locale]
        )
      end

      def initialize(current_user:, ability:, locale: nil)
        @current_user = current_user
        @ability = ability
        @locale = resolve_locale(locale)
      end

      # Creates a new content of the template. Raises when the template is unknown or not creatable,
      # when none of the given attributes is writable, or when validation fails.
      def create(template_name:, data:)
        template = DataCycleCore::Mcp::TemplateLookup.creatable_template_thing!(template_name)
        @ability.authorize!(:create, template)

        applied, ignored = partition_attributes(data, template)
        no_writable_attribute!(template, ignored) if applied.blank?

        # Writing AND evaluating in the write language -- see #with_write_locale.
        with_write_locale do
          content = DataCycleCore::DataHashService.create_internal_object(template.thing_template, nested_data_hash(applied, template), @current_user)

          # Validation errors roll the creation back (create_internal_object ->
          # ActiveRecord::Rollback), but the object keeps id and persisted? -- so check against the
          # database rather than reporting a non-existent record as a success.
          validation_error!(content) if content.errors.present? || !DataCycleCore::Thing.exists?(content.id)

          result(content, applied:, ignored:, created: true)
        end
      end

      # A partial update: only the given attributes are written, all others stay unchanged. A locale
      # not yet present is created as a further translation.
      def update(id:, data:)
        content = DataCycleCore::Thing.find(id)
        @ability.authorize!(:update, content)
        bad_request!('id', "content '#{id}' is embedded and can only be written through its parent content", 'embedded_content') if content.embedded?

        applied, ignored = partition_attributes(data, content)
        no_writable_attribute!(content, ignored) if applied.blank?

        # Writing AND evaluating in the write language -- see #with_write_locale. Here it is the only
        # proof of success: the return value of set_data_hash_with_translations is useless as a
        # signal, being nil on success too (the transaction ends there on
        # `next if previous_datahash_changes.blank?`).
        with_write_locale do
          content.set_data_hash_with_translations(data_hash: nested_data_hash(applied, content), current_user: @current_user)

          validation_error!(content) if content.errors.present?

          result(content.reload, applied:, ignored:, created: false)
        end
      end

      private

      # Every write AND the evaluation of its result run in the write language, because
      # Content#errors and #warnings are language-bound: both return the bucket of I18n.locale
      # (Content::Content#errors -> @errors[I18n.locale]), and they are filled in
      # Content::DataHash#validate under the language being written in.
      #
      # Read outside this block, what would stand there is the bucket of the REQUEST language -- the
      # API controllers do not set I18n.locale, so it stays the instance's default language. On every
      # write into another language (that is, on exactly the route by which a further translation is
      # added) it would be empty, with three consequences: a rolled-back #update would come back as a
      # success complete with applied_attributes, the error of a #create would carry an empty field
      # list, and warnings (including the "no changes" warning from Content::DataHash#no_changes)
      # would never reach the client.
      def with_write_locale(&)
        I18n.with_locale(@locale, &)
      end

      # Built once per writer: #names and the API names behind it cost one query each but are needed
      # both when slicing and when building the response. A writer serves exactly one tool call and
      # therefore exactly one template -- the content passed changes (the template thing on create,
      # the created record afterwards), the template behind it does not.
      def writable_attributes(content)
        @writable_attributes ||= DataCycleCore::Mcp::WritableAttributes.new(content)
      end

      def partition_attributes(data, content)
        given = data.to_h.stringify_keys
        applied = given.slice(*writable_attributes(content).names)

        [applied, given.keys - applied.keys]
      end

      # Brings the flat attribute hash into the shape create_internal_object and
      # set_data_hash_with_translations expect -- translatable attributes under the target language,
      # the rest language-neutral.
      def nested_data_hash(applied, content)
        translated = applied.slice(*content.translatable_property_names)

        {
          translations: { @locale.to_s => translated },
          datahash: applied.except(*translated.keys)
        }
      end

      def result(content, applied:, ignored:, created:)
        {
          id: content.id,
          template_name: content.template_name,
          locale: @locale.to_s,
          # The title in the WRITTEN language -- #with_write_locale ensures the default locale's
          # title does not stand here and confirm an added en update with the de title.
          title: content.title,
          created:,
          applied_attributes: applied.keys.sort,
          # What set_data_hash actually CHANGED. applied_attributes names the attributes that were
          # passed and accepted -- but an attribute that already carried this value is not written
          # among them: set_data_hash slices the schema down to the diff keys and answers an empty
          # diff with the warning "no changes" (Content::DataHash#no_changes). Without this list,
          # "written" is indistinguishable from "was already so", and an LLM reports a change that
          # was none.
          changed_attributes: content.previous_datahash_changes.to_h.keys.sort,
          ignored_attributes: ignored.sort,
          # The commonest reason for an ignored attribute is the API name from get_schema instead of
          # the internal key (odta:length -> length). Shipping the translation along saves the client
          # the guessing step that otherwise leads to a second silent failed attempt.
          attribute_name_corrections: writable_attributes(content).suggestions_for(ignored).presence,
          warnings: content.warnings.full_messages,
          data_pool: content.try(:data_pool).to_a.map(&:name),
          external_source: content.external_source&.name
        }.compact
      end

      # The "data was empty" case lands here too: an empty hash is schema-conformant (data is
      # deliberately open, see Tools::CreateContent), and without a branch of its own the message
      # would read "(ignored: )" -- an error message that does not name the error.
      def no_writable_attribute!(content, ignored)
        corrections = writable_attributes(content).suggestions_for(ignored)
        detail = [
          if ignored.blank?
            "no attributes given for template '#{content.template_name}' -- 'data' must be a flat hash of attribute names and values"
          else
            "none of the given attributes is writable for template '#{content.template_name}' (ignored: #{ignored.join(', ')})"
          end
        ]
        detail << "use the internal attribute names instead of the api names: #{corrections.map { |api_name, name| "#{api_name} -> #{name}" }.join(', ')}" if corrections.present?
        detail << 'call list_writable_attributes for the writable attribute names'

        bad_request!('data', detail.join(' -- '), 'no_writable_attribute')
      end

      def resolve_locale(locale)
        return I18n.default_locale if locale.blank?

        bad_request!('locale', "unknown locale '#{locale}' (available: #{I18n.available_locales.join(', ')})") unless I18n.available_locales.include?(locale.to_sym)

        locale.to_sym
      end

      # Several errors at once (and therefore not through Mcp::BadRequest): a failed validation
      # names EVERY violated rule, so a client does not work through one error per attempt.
      def validation_error!(content)
        errors = content.errors.full_messages.map { |message| { parameter_path: 'data', type: 'validation_error', detail: message } }

        raise DataCycleCore::Error::Api::BadRequestError, errors
      end
    end
  end
end
