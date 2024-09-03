import UserInfoActivity from "../components/user_info_activity";

export default function () {
	DataCycle.registerAddCallback(
		".user-info-activity",
		"user-info-activity",
		(e) => new UserInfoActivity(e),
	);
}
