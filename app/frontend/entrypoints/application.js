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

import jQuery from 'jquery';
window.$ = window.jQuery = jQuery;
global.jQuery = jQuery;

import _ from 'lodash';
window._ = _;

import 'jquery-serializejson';
import 'jquery-ujs';

// import Rails from '@rails/ujs';
import 'lazysizes';
import 'lazysizes/plugins/unveilhooks/ls.unveilhooks.js';
import CalloutHelpers from '~/javascripts/helpers/callout_helpers';
import '~/javascripts/helpers/array_helpers';
import '~/javascripts/helpers/number_helpers';
import '~/javascripts/helpers/string_helpers';
import ActionCable from 'actioncable';

window.actionCable = ActionCable.createConsumer();

import * as initializers from '~/javascripts/initializers';

$(function () {
  _.chain(initializers)
    .omit(['foundationInit', 'validationInit'])
    .values()
    .forEach(value => value())
    .value();

  initializers.foundationInit();
  initializers.validationInit();

  // Rails.start();

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
