class BasicSelect2 {
  constructor(element) {
    this.$element = $(element);
    this.query = {};
    this.config = this.$element.data();
    this.defaultOptions = {
      allowClear: true,
      dropdownParent: this.$element.parent(),
      createTag: this.createTag.bind(this)
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
    this.$element.closest('form').on('reset', this.reset.bind(this));
    this.$element.on('dc:import:data', this.import.bind(this));
    this.$element.on('dc:select:destroy', this.destroy.bind(this));
  }
  reset(_event) {
    this.$element.val(null).trigger('change', { type: 'reset' });
  }
  destroy(_event) {
    this.$element.select2('destroy');
    this.$element.closest('form').off('reset');
    this.$element.off('dc:import:data');
    this.$element.off('dc:select:destroy');
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
  copySelect2Classes(data, container) {
    if (data.class) {
      $(container).addClass(data.class);
    } else if (data.element) {
      $(container).addClass($(data.element).attr('class'));
    }
  }
  decorateResult(result) {
    $(result).html(function (index, value) {
      if (value != undefined) {
        var text = value.split(' &gt; ');
        text[text.length - 1] = '<span class="select2-option-title">' + text[text.length - 1] + '</span>';
        return text.join(' > ');
      }
    });
  }
  removeTreeLabel(result) {
    if (!this.config.treeLabel) return;

    $(result).html((index, value) => {
      if (value != undefined) {
        return value.replace(this.config.treeLabel + ' &gt; ', '');
      }
    });
  }
  removeTreeLabelFromSelection(text) {
    if (!this.config.treeLabel) return text;

    return text.replace(this.config.treeLabel + ' > ', '');
  }
  createTag(params) {
    let term = $.trim(params.term);

    if (term === '') {
      return null;
    }

    return {
      id: term,
      name: term,
      newTag: true
    };
  }
}

module.exports = BasicSelect2;
