import ExternalConnectionButton from "../components/external_connections/external_connection_button";
import AddExternalSystemButton from "../components/external_connections/add_external_system_button";

export default function () {
	DataCycle.initNewElements(
		"a.external-connection-button:not(.dcjs-external-connection-button)",
		(e) => new ExternalConnectionButton(e),
	);

	DataCycle.initNewElements(
		"form.new-external-connection-form:not(.dcjs-add-external-system-button)",
		(e) => new AddExternalSystemButton(e),
	);
}
