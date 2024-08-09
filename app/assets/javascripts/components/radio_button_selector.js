import CheckBoxSelector from "./check_box_selector";

class RadioButtonSelector extends CheckBoxSelector {
	constructor(element) {
		super(element);
		this.$inputFields = this.$element.find("> li > :radio");
	}
	setInputValue(item, value) {
		if (value?.includes($(item).val())) $(item).prop("checked", true);
	}
}

export default RadioButtonSelector;
