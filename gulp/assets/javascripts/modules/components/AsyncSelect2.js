var BasicSelect2 = require('./basic_select2');

class AsyncSelect2 extends BasicSelect2 {
  constructor(element) {
    super(element);

    this.additionalOptionMethods = ['escapeMarkup', 'templateResult'];
  }
  initSelect2() {
    this.select2Object = this.$element.select2(this.defaultoptions);
  }
  import(event, data) {
    if (!data.value || !data.value.length) return;

    let value = this.$element.val();
    if (!Array.isArray(value)) value = [value].filter(el => el !== null);
    if (!Array.isArray(data.value)) data.value = [data.value].filter(el => el !== null);
    let diff = data.value.diff(value);

    if (diff.length) this.loadNewOptions(diff);
  }
  loadNewOptions(ids) {
    let aliasIds = this.config.aliasIds || false;
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
        if (aliasIds && value.classification_alias_id != undefined) value.id = value.classification_alias_id;
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
}

module.exports = AsyncSelect2;
