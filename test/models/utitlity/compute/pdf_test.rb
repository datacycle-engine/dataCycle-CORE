# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class PdfTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Compute::Pdf
        end

        test 'width and height are not implemented and return nil' do
          assert_nil(subject.width(computed_parameters: {}))
          assert_nil(subject.height(computed_parameters: {}))
        end

        test 'exif_value reads a metadata path from the pdf' do
          pdf = struct_double(metadata: { 'pdf_properties' => { 'pages' => 7 } })

          DataCycleCore::Pdf.stub(:find_by, pdf) do
            assert_equal(7, subject.exif_value('pdf-id', ['pdf_properties', 'pages']))
          end
        end

        test 'exif_value returns nil for a missing pdf or a blank path' do
          DataCycleCore::Pdf.stub(:find_by, nil) do
            assert_nil(subject.exif_value('missing', ['pages']))
          end

          DataCycleCore::Pdf.stub(:find_by, struct_double(metadata: {})) do
            assert_nil(subject.exif_value('pdf-id', nil))
          end
        end

        test 'extract_content returns the content metadata' do
          pdf = struct_double(metadata: { 'content' => 'extracted text' })

          DataCycleCore::Pdf.stub(:find_by, pdf) do
            assert_equal('extracted text', subject.extract_content(content: pdf_content, computed_parameters: { 'asset' => 'pdf-id' }))
          end
        end

        test 'extract_content returns nil when the pdf is missing' do
          DataCycleCore::Pdf.stub(:find_by, nil) do
            assert_nil(subject.extract_content(content: pdf_content, computed_parameters: { 'asset' => 'missing' }))
          end
        end

        test 'thumbnail_url returns nil when the pdf has no attached file' do
          DataCycleCore::Pdf.stub(:find_by, unattached_asset_double) do
            assert_nil(subject.thumbnail_url(**compute_args))
          end
        end

        test 'preview_url returns nil when the pdf has no attached file' do
          DataCycleCore::Pdf.stub(:find_by, unattached_asset_double) do
            assert_nil(subject.preview_url(**compute_args))
          end
        end

        # #50159: the thumbnailUrl of a pdf has to point at the linked preview image,
        # the preview rendered from the pdf itself is only the fallback
        test 'thumbnail_url returns the url of the linked preview image when present' do
          value = subject.thumbnail_url(**compute_args(
            computed_parameters: { 'asset' => 'pdf-id', 'thumbnail_image' => [{ 'thumbnail_url' => 'https://cdn.test/image-thumb.jpg' }] },
            parameters: ['thumbnail_image.thumbnail_url', 'asset']
          ))

          assert_equal('https://cdn.test/image-thumb.jpg', value)
        end

        test 'thumbnail_url falls back to the pdf preview when the linked preview image has no url' do
          DataCycleCore::Pdf.stub(:find_by, attached_asset_double(url: 'https://cdn.test/pdf-thumb.png')) do
            DataCycleCore::ActiveStorageService.stub(:with_current_options, ->(&block) { block.call }) do
              value = subject.thumbnail_url(**compute_args(
                computed_parameters: { 'asset' => 'pdf-id', 'thumbnail_image' => nil },
                parameters: ['thumbnail_image.thumbnail_url', 'asset']
              ))

              assert_equal('https://cdn.test/pdf-thumb.png', value)
            end
          end
        end

        test 'thumbnail_url and preview_url return the processed url for an attached pdf' do
          DataCycleCore::Pdf.stub(:find_by, attached_asset_double(url: 'https://cdn.test/pdf-preview.png')) do
            DataCycleCore::ActiveStorageService.stub(:with_current_options, ->(&block) { block.call }) do
              assert_equal('https://cdn.test/pdf-preview.png', subject.thumbnail_url(**compute_args))
              assert_equal('https://cdn.test/pdf-preview.png', subject.preview_url(**compute_args))
            end
          end
        end

        test 'thumbnail_url and preview_url rescue ActiveStorage errors and return nil' do
          DataCycleCore::Pdf.stub(:find_by, attached_asset_double(raises: true)) do
            DataCycleCore::ActiveStorageService.stub(:with_current_options, ->(&block) { block.call }) do
              assert_nil(subject.thumbnail_url(**compute_args))
              assert_nil(subject.preview_url(**compute_args))
            end
          end
        end

        # the same, through the compute configuration of the PDF template
        test 'thumbnail_url of a stored pdf resolves the thumbnail_url of the linked preview image' do
          image = DataCycleCore::TestPreparations.create_content(
            template_name: 'Bild',
            data_hash: { name: 'Vorschaubild', thumbnail_url: 'https://cdn.test/image-thumb.jpg' }
          )
          pdf = DataCycleCore::TestPreparations.create_content(
            template_name: 'PDF',
            data_hash: { name: 'PDF mit Vorschaubild', thumbnail_image: [image.id] }
          )

          assert_equal('https://cdn.test/image-thumb.jpg', pdf.thumbnail_url)
        end

        # the parameter order in the template matters: with image_proxy enabled the linked image
        # exposes its virtual_thumbnail_url as thumbnailUrl in the api, so the pdf has to use that
        # one and not the raw active storage variant. A content_url on the image is what makes
        # image_proxy compute a virtual_thumbnail_url at all.
        test 'thumbnail_url of a stored pdf prefers the virtual_thumbnail_url of the linked preview image' do
          image = DataCycleCore::TestPreparations.create_content(
            template_name: 'Bild',
            data_hash: {
              name: 'Vorschaubild mit image_proxy',
              content_url: 'https://cdn.test/original.jpg',
              thumbnail_url: 'https://cdn.test/image-thumb.jpg'
            }
          )

          assert_predicate(image.virtual_thumbnail_url, :present?)
          assert_not_equal(image.thumbnail_url, image.virtual_thumbnail_url)

          pdf = DataCycleCore::TestPreparations.create_content(
            template_name: 'PDF',
            data_hash: { name: 'PDF mit imgproxy-Vorschaubild', thumbnail_image: [image.id] }
          )

          assert_equal(image.virtual_thumbnail_url, pdf.thumbnail_url)
        end

        # without a linked preview image nothing changes for existing pdfs — the value stays the
        # preview rendered from the pdf itself (named after the pdf, not after an image)
        test 'thumbnail_url of a stored pdf falls back to the preview rendered from the pdf' do
          asset = upload_pdf('test.pdf')
          # render the preview up front: doing it inside the compute would run the transform job,
          # which resets ActiveStorage::Current and drops the url_options again
          asset.file.preview(DataCycleCore::Utility::Compute::Extensions::AssetPreviewUrlExtension::THUMBNAIL_VARIATION).processed

          pdf = with_asset_host do
            DataCycleCore::TestPreparations.create_content(
              template_name: 'PDF',
              data_hash: { name: 'PDF ohne Vorschaubild', asset: asset.id }
            )
          end

          assert_empty(pdf.thumbnail_image)
          assert_includes(pdf.thumbnail_url.to_s, 'test.png')
        end

        # the acceptance criterion of #50159: thumbnailUrl and dc:previewUrl must not be the same
        # value any more. preview_url keeps pointing at the page rendered from the pdf, so adding
        # the linked parameters to it as well would reintroduce the ticket.
        test 'thumbnail_url and preview_url of a stored pdf differ when a preview image is linked' do
          asset = upload_pdf('test.pdf')
          asset.file.preview(DataCycleCore::Utility::Compute::Extensions::AssetPreviewUrlExtension::THUMBNAIL_VARIATION).processed
          asset.file.preview({}).processed
          image = DataCycleCore::TestPreparations.create_content(
            template_name: 'Bild',
            data_hash: { name: 'Vorschaubild für previewUrl', thumbnail_url: 'https://cdn.test/acceptance-thumb.jpg' }
          )

          pdf = with_asset_host do
            DataCycleCore::TestPreparations.create_content(
              template_name: 'PDF',
              data_hash: { name: 'PDF mit Vorschaubild und Datei', asset: asset.id, thumbnail_image: [image.id] }
            )
          end

          assert_equal('https://cdn.test/acceptance-thumb.jpg', pdf.thumbnail_url)
          assert_includes(pdf.preview_url.to_s, 'test.png')
          assert_not_equal(pdf.preview_url, pdf.thumbnail_url)
        end

        private

        # generating an active storage url needs ActiveStorage::Current.url_options, which
        # DataCycleCore::ActiveStorageService fills from config.asset_host — unset in the test env
        def with_asset_host(host = 'http://test.host')
          original = Rails.application.config.asset_host
          Rails.application.config.asset_host = host
          yield
        ensure
          Rails.application.config.asset_host = original
        end

        def compute_args(computed_parameters: { 'asset' => 'pdf-id' }, parameters: ['asset'])
          {
            content: pdf_content,
            key: 'thumbnail_url',
            computed_parameters:,
            computed_definition: { 'compute' => { 'parameters' => parameters } }
          }
        end

        def pdf_content
          asset_content_double
        end
      end
    end
  end
end
