// Classification Selctor in Edit Forms
var ConfirmationModal = require('./../components/confirmation_modal');
require('select2');
require('select2/i18n/de');
$.fn.select2.defaults.set('language', $.fn.select2.amd.require('select2/i18n/de'));
var select2_helpers = require('./../helpers/select2_helpers');

module.exports.initialize = function() {
  let init = function(element) {
    $('.edit-content-form .form-element.classification.check_box > ul.classification-checkbox-list').on(
      'dc:import:data',
      function(event, data) {
        $(event.target)
          .find('> li > :checkbox')
          .each((_, item) => {
            if (data.value !== undefined && data.value.includes($(item).val())) $(item).prop('checked', true);
          });
      }
    );

    $('.auto-tagging-button').on('click', event => {
      $(event.target)
        .closest('.form-element')
        .find('> .v-select > select')
        .val(null)
        .trigger('change');
    });

    $(element)
      .find('.async-select')
      .each(function() {
        var query = {};
        var tree_label = $(this).data('tree-label');
        var alias_ids = $(this).data('alias-ids') || false;
        var max = $(this).data('max');
        var that = this;

        $(this).on('dc:import:data', (event, data) => {
          if (data.value && data.value.length) {
            let async_select = $(event.target);
            let value = async_select.val();
            if (!Array.isArray(value)) value = [value].filter(el => el !== null);
            if (!Array.isArray(data.value)) data.value = [data.value].filter(el => el !== null);
            let diff = data.value.diff(value);
            if (diff.length) {
              $.ajax({
                type: 'GET',
                url: window.DATA_CYCLE_ENGINE_PATH + '/classifications/find',
                data: {
                  ids: diff
                },
                dataType: 'json',
                contentType: 'application/json'
              }).then(data => {
                data = data.map(value => {
                  if (alias_ids && value.classification_alias_id != undefined) value.id = value.classification_alias_id;
                  else if (value.classification_id != undefined) value.id = value.classification_id;
                  return value;
                });

                data.forEach(element => {
                  let option = new Option(element.name, element.id, true, true);
                  option.title = element.title;
                  async_select.append(option).trigger('change');

                  // manually trigger the `select2:select` event
                  async_select.trigger({
                    type: 'select2:select',
                    params: {
                      data: element
                    }
                  });
                });
              });
            }
          }
        });

        $(this).select2({
          allowClear: true,
          minimumInputLength: 2,
          dropdownParent: $(that).parent(),
          escapeMarkup: function(m) {
            return m;
          },
          templateResult: function(data) {
            if (data.loading) {
              return data.title;
            }

            var term = query.term || '';
            var result = data.title ? select2_helpers.markMatch(data.title, term) : null;
            select2_helpers.removeTreeLabel(result, tree_label);
            select2_helpers.decorateResult(result);

            if (data.description) {
              result.attr('title', data.title + '\n\n' + data.description);
              data.title = data.title + '\n\n' + data.description;
            }

            return result;
          },
          templateSelection: function(data) {
            data.selected = true;
            data.text = data.name || data.text;
            $(data.element).text(data.text);
            return data.text;
          },
          ajax: {
            url: window.DATA_CYCLE_ENGINE_PATH + '/classifications/search',
            delay: 250,
            data: function(params) {
              $(that)
                .data('select2')
                .$container.addClass('select2-loading');
              query = params;
              return {
                q: params.term,
                tree_label: tree_label,
                max: max
              };
            },
            processResults: function(data) {
              $(that)
                .data('select2')
                .$container.removeClass('select2-loading');
              return {
                results: data.map(value => {
                  if (alias_ids && value.classification_alias_id != undefined) value.id = value.classification_alias_id;
                  else if (value.classification_id != undefined) value.id = value.classification_id;
                  return value;
                })
              };
            }
          }
        });

        $(this)
          .closest('form')
          .on('reset', event => {
            $(this)
              .val(null)
              .trigger('change', { type: 'reset' });
          });
      });

    $(element)
      .find('.single-select, .multi-select')
      .each(function() {
        var query = {};
        var tree_label = $(this).data('tree-label');
        var that = this;

        $(this).on('dc:import:data', (event, data) => {
          if (data.value && data.value.length) {
            let value = $(event.target).val();
            if (!Array.isArray(value)) value = [value];
            if (!Array.isArray(data.value)) data.value = [data.value];
            value = value.filter(Boolean);
            data.value = data.value.filter(Boolean);

            let diff = data.value.diff(value);
            if (diff.length)
              $(event.target)
                .val(value.concat(diff))
                .trigger('change');
          }
        });

        $(this).on('dc:create:option', (event, data) => {
          let newOption = new Option(data.text, data.id, false, false);
          $(event.currentTarget)
            .append(newOption)
            .trigger('change');
        });

        $(this).select2({
          allowClear: true,
          width: '100%',
          dropdownParent: $(that).parent(),
          templateResult: function(data) {
            var title = $(data.element).data('title');

            if (data.loading) {
              return data.text;
            }

            var term = query.term || '';
            var text_value = title || data.text;

            var result = text_value ? select2_helpers.markMatch(text_value, term) : null;
            select2_helpers.removeTreeLabel(result, tree_label);
            select2_helpers.decorateResult(result);

            return result;
          },
          language: {
            searching: function(params) {
              query = params;

              return '';
            }
          },
          templateSelection: function(data) {
            return select2_helpers.removeTreeLabelFromSelection(data.text, tree_label);
          },
          matcher: function(params, data) {
            // If there are no search terms, return all of the data
            if (params.term === undefined || params.term.trim() === '') {
              return data;
            }

            // Do not display the item if there is no 'text' property
            if (typeof data.text === 'undefined') {
              return null;
            }

            // Skip if there is no 'children' property
            if (data.element.tagName === 'OPTGROUP' && typeof data.children === 'undefined') {
              return null;
            }

            // `data.children` contains the actual options that we are matching against
            var filteredChildren = [];
            $.each(data.children, function(idx, child) {
              if (
                child.text.toLowerCase().indexOf(params.term.toLowerCase()) > -1 ||
                (child.title !== undefined && child.title.toLowerCase().indexOf(params.term.toLowerCase()) > -1)
              ) {
                filteredChildren.push(child);
              }
            });

            // If we matched any of the timezone group's children, then set the matched children on the group
            // and return the group object
            if (filteredChildren.length) {
              var modifiedData = $.extend({}, data, true);
              modifiedData.children = filteredChildren;

              // You can return modified objects from here
              // This includes matching the `children` how you want in nested data sets
              return modifiedData;
            }

            // `params.term` should be the term that is used for searching
            // `data.text` is the text that is displayed for the data object
            if (
              data.text.toLowerCase().indexOf(params.term.toLowerCase()) > -1 ||
              (data.title !== undefined && data.title.toLowerCase().indexOf(params.term.toLowerCase()) > -1)
            ) {
              return data;
            }

            // Return `null` if the term should not be displayed
            return null;
          }
        });

        $(this)
          .closest('.form-element')
          .on('dc:upload:filesChanged', event => {
            event.preventDefault();

            reloadData(this);
          });

        $(this)
          .closest('form')
          .on('reset', event => {
            $(this)
              .val(null)
              .trigger('change', { type: 'reset' });
          });
      });
  };

  function removeHandlers(element) {
    $(element)
      .find('.single-select, .multi-select, .async-select')
      .each((_, element) => {
        $(element).select2('destroy');
      });
  }

  function reloadData(elem) {
    let reloadPath = $(elem).data('reload-path');
    let type = $(elem).data('type');

    if (!reloadPath || !reloadPath.length || !type || !type.length) return;

    $.getJSON(reloadPath, { type: type }).done(data => {
      if (!data || !data.length) return;

      data.forEach(d => {
        if (!$(elem).find("option[value='" + d[1] + "']").length)
          $(elem)
            .append(new Option(d[0], d[1], false, false))
            .trigger('change');
      });
    });
  }

  $(document).on('dc:html:changed', '*', event => {
    init(event.target);
  });

  init(document);
};
