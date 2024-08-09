import ScheduleEditor from "../components/schedule_editor";

export default function () {
	DataCycle.registerAddCallback(
		".schedule-editor",
		"schedule-editor",
		(e) => new ScheduleEditor(e),
	);
}
