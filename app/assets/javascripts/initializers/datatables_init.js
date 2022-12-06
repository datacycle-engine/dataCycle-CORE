const DataTables = () => import('datatables.net-zf').then(mod => mod.default);

class ActivityList {
  constructor(
    item,
    options = {
      ajax: '/admin/activity_details/summary',
      lengthChange: true,
      columns: [
        { title: 'Activity', data: 'activity_type' },
        { title: 'Count', data: 'data_count' }
      ],
      order: [[1, 'desc']]
    }
  ) {
    this.item = item;
    this.item.dcDataTable = true;
    this.options = options;
    this.dataTable;

    this.setup();
  }
  async setup() {
    const DataTable = await DataTables();

    this.dataTable = new DataTable(this.item, this.options);
  }
}

class ActivityUserList extends ActivityList {
  constructor(item) {
    super(item, {
      ajax: '/admin/activity_details/user_summary',
      lengthChange: true,
      columns: [
        { title: 'User', data: 'user_id' },
        { title: 'E-Mail', data: 'email' },
        { title: 'Activity', data: 'activity_type' },
        { title: 'Count', data: 'data_count' }
      ],
      order: [[3, 'desc']]
    });
  }
}

class ActivityDetails extends ActivityList {
  constructor(item) {
    super(item, {
      ajax: '/admin/activity_details/details',
      lengthChange: true,
      columns: [
        { title: 'User', data: 'user_id' },
        { title: 'E-Mail', data: 'email' },
        { title: 'Activity', data: 'activity_type' },
        { title: 'Last Request', data: 'last_request' },
        { title: 'Controller', data: 'request_controller' },
        { title: 'Action', data: 'request_action' },
        { title: 'Type', data: 'request_type' },
        { title: 'Include', data: 'request_include' },
        { title: 'Fields', data: 'request_fields' },
        { title: 'Filter', data: 'request_filter' },
        { title: 'Page', data: 'request_page' },
        { title: 'Mode', data: 'request_mode' },
        { title: 'Id', data: 'request_id' },
        { title: 'Count', data: 'data_count' }
      ],
      order: [[10, 'desc']]
    });
  }
}

export default function () {
  for (const e of document.querySelectorAll('#activity_list')) new ActivityList(e);
  DataCycle.htmlObserver.addCallbacks.push([
    e => e.id == 'activity_list' && !e.hasOwnProperty('dcDataTable'),
    e => new ActivityList(e)
  ]);

  for (const e of document.querySelectorAll('#activity_user_list')) new ActivityUserList(e);
  DataCycle.htmlObserver.addCallbacks.push([
    e => e.id == 'activity_user_list' && !e.hasOwnProperty('dcDataTable'),
    e => new ActivityUserList(e)
  ]);

  for (const e of document.querySelectorAll('#activity_details')) new ActivityDetails(e);
  DataCycle.htmlObserver.addCallbacks.push([
    e => e.id == 'activity_details' && !e.hasOwnProperty('dcDataTable'),
    e => new ActivityDetails(e)
  ]);
}
