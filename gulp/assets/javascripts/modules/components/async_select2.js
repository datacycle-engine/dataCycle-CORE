var BasicSelect2 = require('./basic_select2');

class AsyncSelect2 extends BasicSelect2 {
  constructor(element) {
    super(element);

    this.aliasIds = this.config.aliasIds || false;
  }
  options() {
    return Object.assign({}, this.defaultOptions, {
      minimumInputLength: 2,
      escapeMarkup: this.escapeMarkup.bind(this),
      templateResult: this.templateResult.bind(this),
      templateSelection: this.templateSelection.bind(this),
      ajax: this.ajaxOptions()
    });
  }
  loadNewOptions(_value, ids) {
    $.ajax({
      type: 'GET',
      url: window.DATA_CYCLE_ENGINE_PATH + this.config.findPath,
      data: {
        ids: ids
      },
      dataType: 'json',
      contentType: 'application/json'
    }).then(data => {
      data = data.map(value => {
        if (this.aliasIds && value.classification_alias_id != undefined) value.id = value.classification_alias_id;
        else if (value.classification_id != undefined) value.id = value.classification_id;
        return value;
      });

      data.forEach(element => {
        let option = new Option(element.name, element.id, true, true);
        option.title = element.title;
        this.$element.append(option).trigger('change');

        // manually trigger the `select2:select` event
        this.$element.trigger({
          type: 'select2:select',
          params: {
            data: element
          }
        });
      });
    });
  }
  escapeMarkup(m) {
    return m;
  }
  templateResult(data) {
    if (data.loading) return;

    let term = this.query.term || '';
    let result = data.full_path || data.name;
    result = this.markMatch(result, term);
    if (this.config.showTreeLabel !== 'true') this.removeTreeLabel(result);
    this.decorateResult(result);
    this.copySelect2Classes(data, result);

    return result;
  }
  templateSelection(data, container) {
    data.selected = true;
    data.text = data.name || data.text;
    $(data.element).html(data.text);
    this.copySelect2Classes(data, container);

    return data.text;
  }
  ajaxOptions() {
    return {
      url: window.DATA_CYCLE_ENGINE_PATH + this.config.searchPath,
      delay: 250,
      data: this.ajaxDataHandler.bind(this),
      processResults: this.ajaxProcessResults.bind(this)
    };
  }
  ajaxDataHandler(params) {
    this.select2Object.$container.addClass('select2-loading');
    this.query = params;
    let returnObject = {
      q: params.term,
      max: this.config.max
    };

    if (this.config.treeLabel)
      Object.assign(returnObject, {
        tree_label: this.config.treeLabel
      });

    if (this.config.queryParams) Object.assign(returnObject, this.config.queryParams);

    return returnObject;
  }
  ajaxProcessResults(data) {
    this.select2Object.$container.removeClass('select2-loading');

    let result = data.map(value => {
      if (this.aliasIds && value.classification_alias_id != undefined) value.id = value.classification_alias_id;
      else if (value.classification_id != undefined) value.id = value.classification_id;

      return value;
    });

    return {
      results: result
    };
  }
}

module.exports = AsyncSelect2;