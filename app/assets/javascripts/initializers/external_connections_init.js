import ExternalConnectionButton from "../components/external_connections/external_connection_button";
import AddExternalSystemButton from "../components/external_connections/add_external_system_button";

export default function () {
	DataCycle.registerAddCallback(
		"a.external-connection-button",
		"external-connection-button",
		(e) => new ExternalConnectionButton(e),
	);

	DataCycle.registerAddCallback(
		"form.new-external-connection-form",
		"add-external-system-button",
		(e) => new AddExternalSystemButton(e),
	);
}
