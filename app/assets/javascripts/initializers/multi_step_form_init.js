import MultiStepForm from "../components/multi_step_form";

export default function () {
	DataCycle.registerAddCallback(
		"form.multi-step",
		"multi-step",
		(e) => new MultiStepForm(e),
	);
}
