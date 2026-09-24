# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Mcp
    # Unit tests for the error translation of a tool call. The core is that the raw exception message
    # does NOT go out as soon as the exception class has a translation key: on a scoped `find`,
    # ActiveRecord phrases the message complete with the WHERE condition and the endpoint's template
    # whitelist, and that used to stand unfiltered in the tool response.
    class ErrorMapperTest < DataCycleCore::TestCases::ActiveSupportTestCase
      RAW_AR_MESSAGE = 'Couldn\'t find DataCycleCore::Thing with \'id\'="x" [WHERE "things"."content_type" != $1 ' \
                       'AND "things"."template_name" IN (\'TouristAttraction\', \'LodgingBusiness\')]'

      test 'a record not found never leaks the query behind it' do
        error = mapped(ActiveRecord::RecordNotFound.new(RAW_AR_MESSAGE))

        assert_equal 'Not found', error[:title]
        assert_equal 'Not found', error[:detail]
        assert_not_includes error.to_s, 'WHERE'
        assert_not_includes error.to_s, 'template_name'
      end

      # An error message is the text a client shows the user and therefore follows the mount's
      # language like every tool description -- it was the only client-visible text of this server
      # hard-wired to :en, on a German mount too. The test checks both languages against the same key
      # so the pass-through cannot be silently lost again.
      test 'the mapped error follows the requested locale' do
        exception = ActiveRecord::RecordNotFound.new(RAW_AR_MESSAGE)

        assert_equal 'Not found', mapped(exception, locale: :en)[:detail]
        assert_equal I18n.t('exceptions.active_record/record_not_found', locale: :de), mapped(exception, locale: :de)[:detail]
      end

      # Without a translation key the message stays -- those the libraries phrase themselves and
      # without query context. The test pins that this is the deliberate remainder and not an
      # oversight.
      test 'an exception class without a translation keeps its own message' do
        error = mapped(CanCan::AccessDenied.new('You are not authorized to access this page.'))

        assert_equal 'You are not authorized to access this page.', error[:detail]
      end

      # The route through which Mcp::AttributeFilter and Mcp::SortScope report their parameter
      # errors: here the detail text belongs in the response, because it tells the client what it
      # passed wrongly.
      test 'a bad request error keeps parameter path and detail' do
        exception = DataCycleCore::Error::Api::BadRequestError.new({
          parameter_path: 'attributes[0]',
          type: 'invalid_parameter',
          detail: "condition for 'bookable' needs at least one of in/not_in"
        })

        error = mapped(exception)

        assert_equal 'attributes[0]', error.dig(:source, :parameter)
        assert_includes error[:detail], 'needs at least one of in/not_in'
      end

      # The counterpart to the test above, from the writing side: Mcp::BadRequest is the ONE place
      # this error originates (Mcp::AttributeFilter, Mcp::SortScope, Mcp::ContentWriter and
      # Tools::Download use it). The test pins the contract between the two sides -- previously every
      # caller built the hash itself, and a forgotten :type went unnoticed because the ErrorMapper
      # then silently falls back to detail for the title.
      test 'a bad_request! from the shared module lands in the mapped shape' do
        raiser = Class.new {
          include DataCycleCore::Mcp::BadRequest

          def blow_up(...) = bad_request!(...)
        }.new

        error = mapped(assert_raises(DataCycleCore::Error::Api::BadRequestError) { raiser.blow_up('sort.attribute', 'not sortable') })

        assert_equal 'sort.attribute', error.dig(:source, :parameter)
        assert_equal 'not sortable', error[:detail]
      end

      test 'bad_request! defaults to the invalid_parameter type and takes another one when given' do
        raiser = Class.new {
          include DataCycleCore::Mcp::BadRequest

          def blow_up(...) = bad_request!(...)
        }.new

        default = assert_raises(DataCycleCore::Error::Api::BadRequestError) { raiser.blow_up('format', 'nope') }
        explicit = assert_raises(DataCycleCore::Error::Api::BadRequestError) { raiser.blow_up('format', 'nope', 'invalid_format') }

        assert_equal DataCycleCore::Mcp::BadRequest::DEFAULT_TYPE, default.data[:type]
        assert_equal 'invalid_format', explicit.data[:type]
      end

      test 'call wraps the mapping in the errors envelope' do
        payload = DataCycleCore::Mcp::ErrorMapper.call(ActiveRecord::RecordNotFound.new(RAW_AR_MESSAGE), locale: :en)

        assert_equal ['Not found'], payload[:errors].pluck(:detail)
      end

      private

      # locale: :en as the test default -- the language is not the subject of the remaining cases,
      # and without it their expectation would hang on the respective instance's default language.
      def mapped(exception, locale: :en)
        DataCycleCore::Mcp::ErrorMapper.mapped_errors(exception, locale:).first
      end
    end
  end
end
