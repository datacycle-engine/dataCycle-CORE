// To see this message, add the following to the `<head>` section in your
// views/layouts/application.html.erb
//
//    <%= vite_client_tag %>
//    <%= vite_javascript_tag 'application' %>
console.log('Vite ⚡️ Rails245');

// Example: Load Rails libraries in Vite.
//
import '@rails/ujs';
//
// import Turbolinks from 'turbolinks'
// import ActiveStorage from '@rails/activestorage'
//
// // Import all channels.
// import.meta.globEager('./**/*_channel.js')
//
// Turbolinks.start()
// ActiveStorage.start()

// Example: Import a stylesheet in app/frontend/index.css
// import '~/index.css'

// app.js - Data cylce Core
window.DATA_CYCLE_ENGINE_PATH = window.DATA_CYCLE_ENGINE_PATH || '';
window.EDITORSELECTORS = [
  '> .object-browser',
  '> .embedded-object',
  '> input[type=text]',
  '> .editor-block > .quill-editor',
  '> .v-select > select.multi-select',
  '> .v-select > select.single-select',
  '> .v-select > select.async-select',
  '> ul.classification-checkbox-list',
  '> ul.classification-radiobutton-list',
  '> .form-element > .flatpickr-wrapper > input[type=text].flatpickr-input',
  '> .geographic > .geographic-map',
  '> :checkbox',
  '> :radio',
  '> :input[type="number"]',
  '> .duration-slider > div > input[type="number"]'
];

import $ from 'jquery';
import 'jquery-serializejson';
// import 'jquery-ujs';
import 'lazysizes';
import 'lazysizes/plugins/unveilhooks/ls.unveilhooks.js';
import CalloutHelpers from '~/javascripts/helpers/callout_helpers';
import '~/javascripts/helpers/array_helpers';
import '~/javascripts/helpers/number_helpers';
import '~/javascripts/helpers/string_helpers';
import ActionCable from 'actioncable';

window.actionCable = ActionCable.createConsumer();

import '~/javascripts/initializers/rails_confirmation_init';
import '~/javascripts/initializers/masonry_init';
import '~/javascripts/initializers/quill_init';
import '~/javascripts/initializers/filter_init';
import '~/javascripts/initializers/blur_init';
import '~/javascripts/initializers/detailheader_init';
import '~/javascripts/initializers/focus_init';
import '~/javascripts/initializers/flash_init';
import '~/javascripts/initializers/counter_init';
import '~/javascripts/initializers/date_picker_init';
import '~/javascripts/initializers/slider_init';
import '~/javascripts/initializers/split_contents_init';
import '~/javascripts/initializers/map_init';
import '~/javascripts/initializers/classifications';
import '~/javascripts/initializers/classification_select_init';
import '~/javascripts/initializers/lazyloading_init';
import '~/javascripts/initializers/datalist_init';
import '~/javascripts/initializers/object_browser_init';
import '~/javascripts/initializers/embedded_objects_init';
import '~/javascripts/initializers/iframe_init';
import '~/javascripts/initializers/assets_init';
import '~/javascripts/initializers/publication_init';
import '~/javascripts/initializers/stored_filters_init';
import '~/javascripts/initializers/dropdown_pane_init';
import '~/javascripts/initializers/htmldiff_init';
import '~/javascripts/initializers/remote_render_init';
import '~/javascripts/initializers/new_contents_init';
import '~/javascripts/initializers/admin_panel_init';
import '~/javascripts/initializers/collection';
import '~/javascripts/initializers/reload_required_init';
import '~/javascripts/initializers/bulk_delete_init';
import '~/javascripts/initializers/content_lock_init';
import '~/javascripts/initializers/schedule_editor_init';
import '~/javascripts/initializers/password_toggle';
import '~/javascripts/initializers/datatables_init';
import '~/javascripts/initializers/conditional_form_field';

// keep validations and foundation last to ensure everything is intialized before saving form values
import '~/javascripts/initializers/foundation_init';
import '~/javascripts/initializers/validation_init';

$(function () {
  // HOME RANDOMIZED IMAGES AND GLASSHACK!
  if ($('.home-container').length) {
    $('.home-container').appendTo('body');
    setTimeout(function () {
      $('.home-container').addClass('show');
    }, 500);
    $('body').addClass('login-page');
  }

  // FIXME: move to OEW with event triggers working
  if ($('#import-content-form').length) {
    $('#import-content-form form').on('submit', event => {
      event.preventDefault();

      let url = $(event.currentTarget).find('input#cms_url').val();

      if (url != undefined && url.length > 0) {
        $(event.currentTarget).siblings('.loading').fadeIn(100);
        $.ajax({
          url: url,
          dataType: 'html'
        })
          .done(data => {
            $(event.currentTarget).siblings('.loading').fadeOut(100);
            if ($(data).filter('#cdb-item-definition').length > 0) {
              $(event.currentTarget).find('input#cms_url').val('');
              let contents = JSON.parse($(data).filter('#cdb-item-definition').first().html());

              if (contents !== undefined) {
                if (contents.title !== undefined) {
                  $('[data-label="Meta-Titel"] > input[type=text]').trigger('dc:import:data', {
                    label: 'Meta-Titel',
                    value: contents.title
                  });
                }

                if (contents.description !== undefined) {
                  $('[data-label="Meta-Description"] > input[type=text]').trigger('dc:import:data', {
                    label: 'Meta-Description',
                    value: contents.description
                  });
                }

                // let markets = [];
                // if (contents.language_relations !== undefined && contents.language_relations.length > 0) markets = contents.language_relations.map(x => Object.keys(x)[0]);

                // if (markets.length > 0) {
                //   $('.edit-content-form input.six-cms-markets').remove();
                //   $('.edit-content-form').append('<input type="hidden" name="cms_import_url" value="' + url + '">');
                //   var markets_html = '';

                //   markets.forEach(element => {
                //     markets_html += '<input type="hidden" class="six-cms-markets" name="six_cms_markets[]" value="' + element + '">';
                //   });
                //   $('.edit-content-form').append(markets_html);
                //   CalloutHelpers.show('Abos werden beim Speichern erstellt.', 'success');
                // } else {
                //   CalloutHelpers.show('Keine Märkte gefunden.', 'alert');
                // }

                if (contents.images !== undefined && contents.images.length > 0) {
                  let image_ids = contents.images.map(i => i.external_key);
                  let label = $('.linked[data-key="thing[datahash][image]"]').first().data('label');

                  $('.linked[data-key="thing[datahash][image]"]')
                    .children('.object-browser')
                    .trigger('dc:import:data', {
                      label: label,
                      external_ids: image_ids
                    });
                  CalloutHelpers.show('Bilder importiert.', 'success');
                } else {
                  CalloutHelpers.show('Keine Bilder gefunden.', 'alert');
                }
              } else {
                CalloutHelpers.show('Keine Daten gefunden.', 'alert');
              }
            } else {
              CalloutHelpers.show('Keine Daten gefunden.', 'alert');
            }
          })
          .fail(() => {
            $(event.currentTarget).siblings('.loading').fadeOut(100);
            CalloutHelpers.show('Fehler beim Importieren von URL: ' + url, 'alert');
          });
      }
    });
  }
});
