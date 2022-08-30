import ScheduleEditor from '../components/schedule_editor';

export default function () {
  var schedule_editors = [];

  for (const element of document.querySelectorAll('.schedule-editor'))
    schedule_editors.push(new ScheduleEditor($(element)));

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('schedule-editor') && !e.hasOwnProperty('dcScheduleEditor'),
    e => schedule_editors.push(new ScheduleEditor($(e)))
  ]);
}
