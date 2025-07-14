export default function (additional_classes) {
	return `<div class="loading ${
		additional_classes ? additional_classes : ""
	}"><i class="fa fa-spinner fa-spin fa-fw"></i></div>`;
}
