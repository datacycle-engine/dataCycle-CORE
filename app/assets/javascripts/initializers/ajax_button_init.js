import LifeCylceButton from "../components/ajax_buttons/life_cycle_button";

export default function () {
	DataCycle.registerAddCallback(
		"a.content-pool-button",
		"life-cycle-button",
		(e) => new LifeCylceButton(e),
	);
}
