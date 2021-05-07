import difference from 'lodash/difference';

class BasicSelect2 {
  constructor(element) {
    this.$element = $(element);
    this.query = {};
    this.config = this.$element.data() || {};
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
    this.$element.closest('.form-element').on('dc:field:reset', this.reset.bind(this));
    this.$element.on('dc:import:data', this.import.bind(this));
    this.$element.on('dc:select:destroy', this.destroy.bind(this));
    this.$element.parent().on('change', '.select2-search__field', this.suppressChangeEvent.bind(this));
  }
  suppressChangeEvent(event) {
    event.stopPropagation();
  }
  reset(_event) {
    this.$element.val(null).trigger('change', { type: 'reset' });
  }
  destroy(_event) {
    this.$element.select2('destroy');
    this.$element.closest('form').off('reset');
    this.$element.off('dc:import:data');
    this.$element.off('dc:select:destroy');
    this.$element.closest('.form-element').off('dc:field:reset');
  }
  initSpecificEventHandlers() {}
  import(_event, data) {
    if (!data.value || !data.value.length) return;

    let value = this.$element.val();
    if (!Array.isArray(value)) value = [value];
    if (!Array.isArray(data.value)) data.value = [data.value];

    value = value.filter(Boolean);
    data.value = data.value.filter(Boolean);
    let diff = difference(data.value, value);

    if (diff.length) this.loadNewOptions(value, diff);
  }
  loadNewOptions(_value, _options) {}
  markMatch(text, term) {
    let match = text.toLowerCase().lastIndexOf(term.toLowerCase());
    let $result = $('<span></span>');

    if (!term.length || match < 0) {
      return $result.html(text);
    }

    $result.html(text.substring(0, match));

    let $match = $('<span class="select2-highlight"></span>');
    $match.html(text.substring(match, match + term.length));

    $result.append($match);
    $result.append(text.substring(match + term.length));

    return $result;
  }
  copySelect2Classes(data, container) {
    if (this.select2Object && (container == undefined || $(container).hasClass('select2-selection__rendered')))
      this.select2Object.$selection.find('.select2-selection__rendered').prop('class', 'select2-selection__rendered');

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
      text: term,
      newTag: true
    };
  }
}

export default BasicSelect2;
