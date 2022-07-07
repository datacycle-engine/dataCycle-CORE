class PasswordToggler {
  constructor(container) {
    this.container = container;
    this.passwordField = this.container.querySelector('input');
    this.passwordToggler = this.container.querySelector('.password-visibility-toggle');

    this.setup();
  }
  setup() {
    if (!this.container || !this.passwordField) return;

    this.addPasswordTogglerHtml();

    this.passwordToggler.addEventListener('click', this.toggleVisibility.bind(this));
    this.passwordField.addEventListener('input', this.changeTogglerVisibility.bind(this));
  }
  addPasswordTogglerHtml() {
    if (this.passwordToggler) return;

    this.passwordField.insertAdjacentHTML(
      'afterend',
      `<span class="password-visibility-toggle ${
        this.passwordField.type == 'password' ? '' : 'password-visible'
      }"></span>`
    );

    this.passwordToggler = this.container.querySelector('.password-visibility-toggle');
  }
  toggleVisibility(event) {
    event.preventDefault();

    this.passwordToggler.classList.toggle('password-visible');
    this.passwordField.type = this.passwordField.type == 'password' ? 'text' : 'password';
  }
  changeTogglerVisibility(_event) {
    if (this.passwordField.value) this.container.classList.add('has-value');
    else this.container.classList.remove('has-value');
  }
}

export default PasswordToggler;
