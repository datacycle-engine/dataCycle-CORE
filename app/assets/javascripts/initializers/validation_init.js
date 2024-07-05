import Validator from "./../components/validator";
import BulkUpdateValidator from "./../components/bulk_update_validator";
import DataCycleNormalizer from "./../components/normalizer";

function initValidator(elem) {
	elem.classList.add("dcjs-validator");
	if (elem.classList.contains("bulk-edit-form") && window.actionCable)
		new BulkUpdateValidator(elem);
	else new Validator(elem);
}

export default function () {
	DataCycle.initNewElements(
		".validation-form:not(.dcjs-validator)",
		initValidator.bind(this),
	);
	DataCycle.initNewElements(
		".normalize-content-button:not(.dcjs-data-cycle-normalizer)",
		(e) => new DataCycleNormalizer(e),
	);
}
