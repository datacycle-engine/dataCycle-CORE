class BasicSelect2 {
  constructor(element) {
    this.$element = $(element);
    this.query = {};
    this.config = element.dataset;
    this.defaultOptions = {
      allowClear: true,
      minimumInputLength: 2,
      dropdownParent: this.$element.parent()
    };
    this.additionalOptionMethods = [];
    this.select2Object = null;
  }
  init() {
    this.initSelect2();
    this.initEventHandlers();
    this.initSpecificEventHandlers();
  }
  options() {
    let select2Options = this.defaultOptions;

    this.additionalOptionMethods.forEach(configOption => {
      if (typeof this[configOption] === 'function') {
        select2Options[configOption] = this[configOption];
      }
    });

    return select2Options;
  }
  initSelect2() {
    this.select2Object = this.$element.select2(this.options);
  }
  initEventHandlers() {
    this.$element.closest('form').on('reset', this.reset);
    this.$element.on('dc:import:data', this.import);
  }
  reset(_event) {
    this.$element.val(null).trigger('change', { type: 'reset' });
  }
  initSpecificEventHandlers() {}
  import(_event, _data) {}
  markMatch(text, term) {
    let match = text.toUpperCase().lastIndexOf(term.toUpperCase());
    let $result = $('<span></span>');

    if (match < 0) {
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
