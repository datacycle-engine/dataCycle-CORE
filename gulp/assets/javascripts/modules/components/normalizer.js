// Normalizer
var object_helpers = require('./../helpers/object_helpers');

var DataCycleNormalizer = function(button, form_element) {
  this.normalize_button = $(button);
  this.normalize_url = this.normalize_button.data('url');
  this.form_element = $(form_element);
  this.form_data = [];
  this.normalized_data = {};

  this.init();
};

DataCycleNormalizer.prototype.init = function() {
  this.normalize_button.on('click', this.normalizeForm.bind(this));
};

DataCycleNormalizer.prototype.normalizeForm = function(event) {
  event.preventDefault();
  this.disableForm();
  this.resetElements();

  this.form_data = this.form_element.serializeArray().filter(value => {
    return value.name != '_method';
  });

  $.ajax({
    type: 'POST',
    url: this.normalize_url,
    data: $.param(this.form_data),
    dataType: 'json'
  })
    .done(data => {
      this.normalized_data = [];
      if (data != undefined) {
        this.mapFieldNamesToValues(data);

        for (let attr_key in this.normalized_data) {
          var normalized_field = $('input[name="thing[datahash]' + attr_key + '"]');

          if (normalized_field.length) {
            switch (this.normalized_data[attr_key][0]) {
              case '+':
                normalized_field.addClass('normalized new').val(this.normalized_data[attr_key][1]);
                break;
              case '-':
                normalized_field.addClass('normalized remove').val('');
                break;
              case '~':
                normalized_field.addClass('normalized change').val(this.normalized_data[attr_key][1]);
                break;
              case '?':
                normalized_field.addClass('normalized change');
                normalized_field
                  .siblings('label')
                  .first()
                  .append('<i class="fa fa-arrow-circle-up change-selector-show-button" aria-hidden="true"></i>');
                this.showChangeSelector(normalized_field, this.normalized_data[attr_key][1]);
                break;
            }
          }
        }
      }
    })
    .fail(data => {
      this.normalize_button.addClass('error');
      $('#' + this.normalize_button.data('toggle')).html(
        this.normalize_button.data('title') + '<br><br>Fehler: ' + data.statusText
      );
    })
    .always(data => {
      this.enableForm();
    });
};

DataCycleNormalizer.prototype.mapFieldNamesToValues = function(data, parent_string = '') {
  if (data != undefined && typeof data == 'object' && !Array.isArray(data)) {
    Object.keys(data).map(key => {
      this.mapFieldNamesToValues(data[key], parent_string + '[' + key + ']');
    });
  } else {
    this.normalized_data[parent_string] = data;
  }
};

DataCycleNormalizer.prototype.showChangeSelector = function(field, options) {
  var list_html =
    '<div class="change-selector" id="' +
    field.prop('id') +
    '_selector" data-target="' +
    field.prop('id') +
    '"><span class="change-selector-title">Vorschläge:</span>';
  for (var i = 0; i < options.length; i++) {
    list_html +=
      '<span class="change-selector-option" data-value="' +
      options[i] +
      '"><i class="fa fa-check change-selector-checkbox" aria-hidden="true"></i>' +
      options[i] +
      '</span>';
  }
  list_html += '<span class="buttons"><a class="change-selector-submit-button button">Übernehmen</a></span></div>';
  field.closest('.form-element').before(list_html);

  this.addEventHandlers(field);
};

DataCycleNormalizer.prototype.addEventHandlers = function(field) {
  field
    .siblings('label')
    .first()
    .find('.change-selector-show-button')
    .off('click')
    .on('click', event => {
      $('#' + field.prop('id') + '_selector').slideToggle();
    });

  $('#' + field.prop('id') + '_selector .change-selector-option')
    .off('click')
    .on('click', event => {
      $('#' + field.prop('id') + '_selector .change-selector-option').removeClass('active');
      $(event.currentTarget).addClass('active');
    });
  $('#' + field.prop('id') + '_selector .change-selector-submit-button')
    .off('click')
    .on('click', event => {
      field.val(
        $('#' + field.prop('id') + '_selector .change-selector-option.active')
          .map((index, element) => {
            return $(element).data('value');
          })
          .toArray()
      );
      $(event.target)
        .closest('.change-selector')
        .slideUp();
    });
};

DataCycleNormalizer.prototype.disableForm = function() {
  this.form_element
    .siblings('.edit-header')
    .find('.submit-edit-form')
    .first()
    .attr('disabled', true);

  $.rails.disableFormElement(
    this.form_element
      .siblings('.edit-header')
      .find('.normalize-content-button')
      .first()
  );
  $.rails.disableFormElements(this.form_element);
};

DataCycleNormalizer.prototype.enableForm = function() {
  this.form_element
    .siblings('.edit-header')
    .find('.submit-edit-form')
    .first()
    .attr('disabled', false);

  $.rails.enableFormElement(
    this.form_element
      .siblings('.edit-header')
      .find('.normalize-content-button')
      .first()
  );
  $.rails.enableFormElements(this.form_element);
};

DataCycleNormalizer.prototype.resetElements = function() {
  this.form_element.find('.normalized').removeClass('normalized new remove change select');
  this.form_element.find('.change-selector').remove();
  $('.change-selector-show-button').remove();
  this.normalize_button.removeClass('error');
  $('#' + this.normalize_button.data('toggle')).html(this.normalize_button.data('title'));
};

module.exports = DataCycleNormalizer;