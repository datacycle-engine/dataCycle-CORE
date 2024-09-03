import PasswordToggler from "../components/password_toggler";

export default function () {
	DataCycle.registerAddCallback(
		".password-field",
		"password-toggler",
		(e) => new PasswordToggler(e),
	);
}
