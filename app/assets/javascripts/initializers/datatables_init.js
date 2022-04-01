const DataTables = () => import('datatables.net-zf').then(mod => mod.default);
const DataTableButtons = () => import('datatables.net-buttons-zf').then(mod => mod.default);

export default async function () {
  if (document.querySelector('#activity_list, #activity_user_list, #activity_details')) {
    const dataTables = await DataTables();
    const buttons = await DataTableButtons();

    dataTables();
    buttons(window, $);

    $('#activity_list').DataTable({
      ajax: '/admin/activity_details/summary',
      columns: [
        { title: 'Activity', data: 'activity_type' },
        { title: 'Count', data: 'data_count' }
      ],
      order: [[1, 'desc']]
    });

    $('#activity_user_list').DataTable({
      ajax: '/admin/activity_details/user_summary',
      columns: [
        { title: 'User', data: 'user_id' },
        { title: 'E-Mail', data: 'email' },
        { title: 'Activity', data: 'activity_type' },
        { title: 'Count', data: 'data_count' }
      ],
      order: [[3, 'desc']]
    });

    $('#activity_details').DataTable({
      ajax: '/admin/activity_details/details',
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
