class WatchList {
  static selector = ".watch_lists";
  static className = "dcjs-watch_lists";
  constructor(element) {
    this.watchList = element
    this.dataMode = this.watchList.querySelector("#search-form")?.dataset.mode;
    if (this.dataMode != "grid" && this.dataMode != "list") return;

    this.selectionEnabled = false;
    this.itemAccessor = `li.${this.dataMode}-item`;

    this.resultSet = this.watchList.querySelector(`#search-results .${this.dataMode}`);
    this.watchListFooter = this.watchList.querySelector(".watch-list-footer");
    this.selectButton = this.watchList.querySelector(".edit a.select-things");
    this.closeButton = this.watchList.querySelector(".buttons .close-selection");
    this.chosenCounter = this.watchListFooter.querySelector(".chosen-counter");
    this.deleteItemsButton = this.watchListFooter.querySelector(".buttons .remove-selected-from-collection-link");
    this.deleteItemsBaseUrl = this.deleteItemsButton?.getAttribute("action")?.split("?")[0] || "";
    this.resultCount = this.watchList.querySelector("#search-form .result-count");
    this.selectionButton = this.watchList.querySelector('.select-things');

    this.watchList.querySelector(".edit a.select-things").addEventListener("click", this.handleSelection.bind(this));
    this.watchList.querySelector(".buttons .close-selection").addEventListener("click", this.removeSelection.bind(this));

    this.resultSet.addEventListener("turbo:submit-end", (event) => {
      if (event.target.closest(".remove-from-watchlist-link")) {
        this.emptyResultCount();
      }
    });

    this.deleteItemsButton?.addEventListener("turbo:submit-end", () => {
      this.removeSelection();
      this.emptyResultCount();
    });

    this.resultObserver = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.addedNodes.length > 0 && this.selectionEnabled) {
          this.enableCheckboxes();
          break;
        }
      }
    });

    this.resultObserver.observe(this.resultSet, {
      childList: true,
      subtree: true,
    });

  }

  handleSelection(event) {
    event.preventDefault();
    event.stopImmediatePropagation();

    this.selectionEnabled? this.removeSelection() : this.setupSelection();
  }

  setupSelection() {
    this.selectionEnabled = true;
    this.chosenItems = [];

    this.selectionButton.classList.add("active");
    this.watchListFooter.classList.remove("hidden");
    this.updateChosenCounter();
    this.enableCheckboxes();
  }

  removeSelection() {
    this.selectionEnabled = false;
    this.watchListFooter.classList.add("hidden");
    this.selectionButton.classList.remove("active");

    this.resultSet.querySelectorAll(`.watch-list-tile-checkbox`).forEach((el) => {
      el.classList.add("hidden");
    });

    this.resultSet.removeEventListener("click", this.setupOnClickEvent.bind(this))

    this.resetSelection();
    this.updateLink();
  }

  resetSelection() {
    this.chosenItems = [];

    this.resultSet
      .querySelectorAll(`.${this.dataMode} ${this.itemAccessor}.active`)
      .forEach((el) => { el.classList.remove("active"); })
  }

  enableCheckboxes() {
    this.resultSet .querySelectorAll(".watch-list-tile-checkbox.hidden").forEach((el) => {
        el.classList.remove("hidden");
      });

    this.resultSet.addEventListener("click", this.setupOnClickEvent.bind(this));
  }

  setupOnClickEvent(event) {
    if (!this.selectionEnabled) return;

    const item = event.target.closest(this.itemAccessor);
    if (!item || !this.resultSet.contains(item)) return;
    this.clickItemsHandler(event, item);
  }

  clickItemsHandler(event, item) {
    const target = event.target;

    if (target.closest("a.toggle-details, .remove-from-watchlist-link") || !item) return;

    event.preventDefault();
    event.stopImmediatePropagation();

    let id = item.dataset["id"]
    this.chosenItems.includes(id)? this.removeObject(id, event) : this.addObject(id);
  }

  addObject(id) {
    if (this.chosenItems.includes(id)) return;

    this.chosenItems.push(id);
    this.resultSet
      .querySelector(`${this.itemAccessor}[data-id="${id}"]`)
      .classList.add("active");

    this.updateLink();
    this.updateChosenCounter();
  }

  removeObject(id) {
    this.chosenItems = this.chosenItems.filter((x) => x !== id);
    this.resultSet.querySelector(`${this.itemAccessor}[data-id="${id}"]`).classList.remove("active");

    this.updateLink();
    this.updateChosenCounter();
  }

  updateLink() {
    const params = new URLSearchParams();
    this.chosenItems.forEach((id) => params.append("thing_id[]", id));
    this.deleteItemsButton.setAttribute(
      "action",
      this.deleteItemsBaseUrl + (params.toString() ? "?" + params.toString() : "")
    );
  }

  updateChosenCounter() {
    const text = this.chosenItems.length === 1? this.chosenCounter.dataset["i18nOne"] : this.chosenCounter.dataset["i18nMany"] ;
    this.chosenCounter.innerHTML = `<strong>${this.chosenItems.length}</strong> ${text}`;
  }

  emptyResultCount() {
    this.resultCount.innerHTML = ""
  }
}

export default WatchList;
