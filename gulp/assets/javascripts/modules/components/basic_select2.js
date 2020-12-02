class BasicSelect2 {
  constructor(element) {
    this.$element = $(element);
    this.query = {};
    this.config = element.dataset;
    this.defaultOptions = {
      allowClear: true,
      dropdownParent: this.$element.parent()
    };
    this.select2Object = null;
  }
  init() {
    this.initSelect2();
    this.initEventHandlers();
    this.initSpecificEventHandlers();
  }
  options() {
    return this.defaultOptions;
  }
  initSelect2() {
    this.$element.select2(this.options());
    this.select2Object = this.$element.data('select2');
  }
  initEventHandlers() {
    this.$element.closest('form').on('reset', this.reset);
    this.$element.on('dc:import:data', this.import);
  }
  reset(_event) {
    this.$element.val(null).trigger('change', { type: 'reset' });
  }
  initSpecificEventHandlers() {}
  import(_event, data) {
    if (!data.value || !data.value.length) return;

    let value = this.$element.val();
    if (!Array.isArray(value)) value = [value];
    if (!Array.isArray(data.value)) data.value = [data.value];

    value = value.filter(Boolean);
    data.value = data.value.filter(Boolean);
    let diff = data.value.diff(value);

    if (diff.length) this.loadNewOptions(value, diff);
  }
  loadNewOptions(_value, _options) {}
  markMatch(text, term) {
    let match = text.toLowerCase().lastIndexOf(term.toLowerCase());
    let $result = $('<span></span>');

    if (!term.length || match < 0) {
      return $result.text(text);
    }

    $result.text(text.substring(0, match));

    let $match = $('<span class="select2-highlight"></span>');
    $match.text(text.substring(match, match + term.length));

    $result.append($match);
    $result.append(text.substring(match + term.length));

    return $result;
  }
  decorateResult(result) {
    $(result).html(function (index, value) {
      if (value != undefined) {
        var text = value.split(' &gt; ');
        text[text.length - 1] = '<span class="select2-option-title">' + text[text.length - 1] + '</span>';
        return text.join(' > ');
      }
    });

    return result;
  }
  removeTreeLabel(result) {
    if (!this.config.treeLabel) return result;

    $(result).html((index, value) => {
      if (value != undefined) {
        return value.replace(this.config.treeLabel + ' &gt; ', '');
      }
    });

    return result;
  }
  removeTreeLabelFromSelection(text) {
    if (!this.config.treeLabel) return text;

    return text.replace(this.config.treeLabel + ' > ', '');
  }
}

module.exports = BasicSelect2;
