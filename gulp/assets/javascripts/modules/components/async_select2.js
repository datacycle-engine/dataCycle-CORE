var BasicSelect2 = require('./basic_select2');

class AsyncSelect2 extends BasicSelect2 {
  constructor(element) {
    super(element);

    this.additionalOptionMethods = ['escapeMarkup', 'templateResult', 'templateSelection'];
    this.aliasIds = this.config.aliasIds || false;
  }
  initSelect2() {
    let options = Object.assign({}, this.options(), this.ajaxOptions());

    console.log(options);

    this.select2Object = this.$element.select2(options);
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
    if (data.loading) {
      return data.title;
    }

    let term = this.query.term || '';
    let result = data.title ? this.markMatch(data.title, term) : null;
    result = this.removeTreeLabel(result);
    result = this.decorateResult(result);

    if (data.description) {
      result.attr('title', data.title + '\n\n' + data.description);
      data.title = data.title + '\n\n' + data.description;
    }

    return result;
  }
  templateSelection(data) {
    data.selected = true;
    data.text = data.name || data.text;
    $(data.element).text(data.text);

    return data.text;
  }
  ajaxOptions() {
    return {
      url: window.DATA_CYCLE_ENGINE_PATH + this.config.searchPath,
      delay: 250,
      data: this.ajaxDataHandler,
      processResults: this.ajaxProcessResults
    };
  }
  ajaxDataHandler(params) {
    this.select2Object.$container.addClass('select2-loading');
    this.query = params;
    let returnObject = {
      q: params.term,
      max: max
    };

    if (this.config.treeLabel)
      Object.assign(returnObject, {
        tree_label: this.config.treeLabel
      });

    return returnObject;
  }
  ajaxProcessResults(data) {
    this.select2Object.$container.removeClass('select2-loading');

    return {
      results: data.map(value => {
        if (this.aliasIds && value.classification_alias_id != undefined) value.id = value.classification_alias_id;
        else if (value.classification_id != undefined) value.id = value.classification_id;
        return value;
      })
    };
  }
}

module.exports = AsyncSelect2;
