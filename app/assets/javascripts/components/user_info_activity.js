class UserInfoActivity {
  constructor(button) {
    this.button = button;
    this.button.classList.add('dcjs-user-info-activity');
    this.searchForm = this.button.closest('form');
    this.downloadPath = this.button.dataset.downloadPath;

    this.setUp();
  }

  setUp() {
    this.addEventListeners();
  }

  addEventListeners() {
    this.button.addEventListener('click', this.downloadUserInfo.bind(this));
  }

  downloadUserInfo() {
    const temp = this.searchForm.action;
    this.searchForm.action = this.downloadPath;
    this.searchForm.submit();
    this.searchForm.action = temp;
  }
}

export default UserInfoActivity;
