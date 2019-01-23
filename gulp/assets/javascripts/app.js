// app.js - Data cylce Core
var $ = require('jquery');
var jquery_to_json = require('jquery-serializejson');
var jqueryujs = require('jquery-ujs');
var foundation = require('foundation-sites');
var lazysizes = require('lazysizes');
var lazysizes_unveilhooks = require('lazysizes/plugins/unveilhooks/ls.unveilhooks.min.js');
var callout_helpers = require('./modules/helpers/callout_helpers');
var array_helpers = require('./modules/helpers/array_helpers');
var number_helpers = require('./modules/helpers/number_helpers');
var string_helpers = require('./modules/helpers/string_helpers');

var initializers = [];
initializers.push(require('./modules/initializers/masonry_init'));
initializers.push(require('./modules/initializers/quill_init'));
initializers.push(require('./modules/initializers/filter_init'));
initializers.push(require('./modules/initializers/blur_init'));
initializers.push(require('./modules/initializers/detailheader_init'));
initializers.push(require('./modules/initializers/focus_init'));
initializers.push(require('./modules/initializers/flash_init'));
initializers.push(require('./modules/initializers/validation_init'));
initializers.push(require('./modules/initializers/counter_init'));
initializers.push(require('./modules/initializers/date_picker_init'));
initializers.push(require('./modules/initializers/slider_init'));
initializers.push(require('./modules/initializers/split_contents_init'));
initializers.push(require('./modules/initializers/map_init'));
initializers.push(require('./modules/initializers/classifications'));
initializers.push(require('./modules/initializers/classification_select_init'));
initializers.push(require('./modules/initializers/lazyloading_init'));
initializers.push(require('./modules/initializers/datalist_init'));
initializers.push(require('./modules/initializers/object_browser_init'));
initializers.push(require('./modules/initializers/embedded_objects_init'));
initializers.push(require('./modules/initializers/iframe_init'));
initializers.push(require('./modules/initializers/assets_init'));
initializers.push(require('./modules/initializers/rails_confirmation_init'));
initializers.push(require('./modules/initializers/publication_init'));
initializers.push(require('./modules/initializers/stored_filters_init'));
initializers.push(require('./modules/initializers/dropdown_pane_init'));
initializers.push(require('./modules/initializers/file_upload_init'));
initializers.push(require('./modules/initializers/htmldiff_init'));
initializers.push(require('./modules/initializers/remote_render_init'));
initializers.push(require('./modules/initializers/new_contents_init'));

$(function() {
  initializers.forEach(element => {
    try {
      element.initialize();
    } catch (err) {
      console.log(err);
    }
  });

  // Initialize Foundation
  Foundation.Tooltip.defaults.clickOpen = false;
  $(document).foundation();

  // HOME RANDOMIZED IMAGES AND GLASSHACK!
  if ($('.home-container').length) {
    $('.home-container').appendTo('body');
    setTimeout(function() {
      $('.home-container').addClass('show');
    }, 500);
    $('body').addClass('login-page');
  }

  // FIXME: move to OEW with event triggers working
  if ($('#import-content-form').length) {
    $('#import-content-form form').on('submit', event => {
      event.preventDefault();

      let url = $(event.currentTarget)
        .find('input#cms_url')
        .val();

      if (url != undefined && url.length > 0) {
        $(event.currentTarget)
          .siblings('.loading')
          .fadeIn(100);
        $.ajax({
          url: url,
          dataType: 'html'
        })
          .done(data => {
            $(event.currentTarget)
              .siblings('.loading')
              .fadeOut(100);
            if ($(data).filter('#cdb-item-definition').length > 0) {
              $(event.currentTarget)
                .find('input#cms_url')
                .val('');
              let contents = JSON.parse(
                $(data)
                  .filter('#cdb-item-definition')
                  .first()
                  .html()
              );

              if (contents !== undefined) {
                if (contents.title !== undefined) {
                  $('[data-label="Meta-Titel"] > input[type=text]').trigger(
                    'import-data',
                    {
                      label: 'Meta-Titel',
                      value: contents.title
                    }
                  );
                }

                if (contents.description !== undefined) {
                  $(
                    '[data-label="Meta-Description"] > .editor-block > .quill-editor'
                  ).trigger('import-data', {
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
                //   callout_helpers.show('Abos werden beim Speichern erstellt.', 'success');
                // } else {
                //   callout_helpers.show('Keine Märkte gefunden.', 'alert');
                // }

                if (
                  contents.images !== undefined &&
                  contents.images.length > 0
                ) {
                  let image_ids = contents.images.map(i => i.external_key);
                  let label = $('.linked[data-label="Bilder"]')
                    .first()
                    .data('label');

                  $('.linked[data-label="Bilder"]')
                    .children('.object-browser')
                    .trigger('import-data', {
                      label: label,
                      external_ids: image_ids
                    });
                  callout_helpers.show('Bilder importiert.', 'success');
                } else {
                  callout_helpers.show('Keine Bilder gefunden.', 'alert');
                }
              } else {
                callout_helpers.show('Keine Daten gefunden.', 'alert');
              }
            } else {
              callout_helpers.show('Keine Daten gefunden.', 'alert');
            }
          })
          .fail(() => {
            $(event.currentTarget)
              .siblings('.loading')
              .fadeOut(100);
            callout_helpers.show(
              'Fehler beim Importieren von URL: ' + url,
              'alert'
            );
          });
      }
    });
  }
});
