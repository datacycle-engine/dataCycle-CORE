import UserInfoActivity from '../components/user_info_activity';

export default function () {
  DataCycle.initNewElements('.user-info-activity:not(.dcjs-user-info-activity)', e => new UserInfoActivity(e));
}
