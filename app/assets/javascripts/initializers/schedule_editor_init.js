import ScheduleEditor from "../components/schedule_editor";

export default function () {
	DataCycle.initNewElements(
		".schedule-editor:not(.dcjs-schedule-editor)",
		(e) => new ScheduleEditor(e),
	);
}
