import PasswordToggler from '../components/password_toggler';

export default function () {
  for (const passwordField of document.getElementsByClassName('password-field')) {
    new PasswordToggler(passwordField);
  }

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('password-field') && !e.classList.contains('dcjs-password-toggler'),
    e => new PasswordToggler(e)
  ]);
}
