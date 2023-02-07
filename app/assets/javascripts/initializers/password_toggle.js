import PasswordToggler from '../components/password_toggler';

export default function () {
  DataCycle.initNewElements('.password-field:not(.dcjs-password-toggler)', e => new PasswordToggler(e));
}
