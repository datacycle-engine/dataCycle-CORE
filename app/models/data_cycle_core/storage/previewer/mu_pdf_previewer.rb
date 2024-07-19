# frozen_string_literal: true

module DataCycleCore
  module Storage
    module Previewer
      class MuPdfPreviewer < ActiveStorage::Previewer::MuPDFPreviewer
        OPTIONS_KEYMAP = {
          resolution: '-r',
          width: '-w',
          height: '-h'
        }.freeze

        private

        def draw_first_page_from(file, &)
          draw(self.class.mutool_path, 'draw', '-F', 'png', *transformed_previewer_options, '-o', '-', file.path, '1', &)
        end

        def transformed_previewer_options
          return [] unless Feature::CustomAssetPreviewer.enabled?

          options = Feature::CustomAssetPreviewer.previewer_options(self.class.name.demodulize.underscore_blanks)

          return [] if options.blank?

          options.flat_map { |k, v| [OPTIONS_KEYMAP[k.to_sym], v.to_s] }
        end
      end
    end
  end
end
