import Validator from "./../components/validator";
import BulkUpdateValidator from "./../components/bulk_update_validator";
import DataCycleNormalizer from "./../components/normalizer";

function initValidator(elem) {
	if (elem.classList.contains("bulk-edit-form") && window.actionCable)
		new BulkUpdateValidator(elem);
	else new Validator(elem);
}

export default function () {
	DataCycle.registerAddCallback(
		".validation-form",
		"validator",
		initValidator.bind(this),
	);
	DataCycle.registerAddCallback(
		".normalize-content-button",
		"data-cycle-normalizer",
		(e) => new DataCycleNormalizer(e),
	);
}
