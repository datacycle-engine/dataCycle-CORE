class ClassificationJumpToParent {
  constructor(item) {
    this.item = item;
    this.item.classList.add('dcjs-classification-jump-to-parent');

    this.setup();
  }
  setup() {
    this.item.addEventListener('click', this.jumptToParent.bind(this));
    this.item.addEventListener('mouseover', this.hoverTree.bind(this));
    this.item.addEventListener('mouseout', this.blurTree.bind(this));
  }
  jumptToParent(event) {
    if (event.target !== this.item) return;
    if (event.clientX - event.target.getBoundingClientRect().left > 15) return;

    event.preventDefault();
    event.stopPropagation();

    const parent = this.item.parentElement.closest('li');

    parent.scrollIntoView({
      behavior: 'smooth',
      block: 'start'
    });

    parent.classList.add('highlight');
    setTimeout(() => parent.classList.remove('highlight'), 1000);
  }
  hoverTree(event) {
    if (event.target !== this.item) return;
    if (event.clientX - event.target.getBoundingClientRect().left > 15) return;

    event.preventDefault();
    event.stopPropagation();

    this.item.parentElement.closest('li').classList.add('hover');
  }
  blurTree(event) {
    event.preventDefault();
    event.stopPropagation();

    this.item.parentElement.closest('li').classList.remove('hover');
  }
}

export default ClassificationJumpToParent;
