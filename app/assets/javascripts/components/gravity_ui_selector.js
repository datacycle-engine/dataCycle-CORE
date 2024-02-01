const positions = {
  top: {
    top: '0',
    left: '50%',
    transform: 'translateX(-50%)',
    iconClass: 'fa-arrow-up'
  },
  'top-right': {
    top: '0',
    right: '0',
    rotate: '45deg',
    iconClass: 'fa-arrow-up'
  },
  right: {
    top: '50%',
    right: '0',
    rotate: '90deg',
    transform: 'translateY(-50%)',
    iconClass: 'fa-arrow-up'
  },
  'bottom-right': {
    bottom: '0',
    right: '0',
    rotate: '135deg',
    iconClass: 'fa-arrow-up'
  },
  bottom: {
    bottom: '0',
    left: '50%',
    rotate: '-180deg',
    transform: 'translateX(-50%)',
    iconClass: 'fa-arrow-up'
  },
  'bottom-left': {
    bottom: '0',
    left: '0',
    rotate: '-135deg',
    iconClass: 'fa-arrow-up'
  },
  left: {
    top: '50%',
    left: '0',
    rotate: '-90deg',
    transform: 'translateY(-50%)',
    iconClass: 'fa-arrow-up'
  },
  'top-left': {
    top: '0',
    left: '0',
    rotate: '-45deg',
    iconClass: 'fa-arrow-up'
  },
  center: {
    top: '50%',
    left: '50%',
    transform: 'translate(-50%, -50%)',
    iconClass: 'fa-circle'
  }
};
for (const position in positions) {
  Object.freeze(positions[position]);
}
Object.freeze(positions);

const IDEAL_PREVIEW_SIZE = 400;

class GravityUiSelector {
  constructor(button) {
    this.button = button;
    this.button.classList.add('dcjs-gravity-ui-selector');
    this.gravitySelecorIcons = [];
    this.thumbContainer = null;
    this.setUp();
  }

  setUp() {
    this.addEventListeners();
  }

  addEventListeners() {
    const imageContainer = this.button.closest('.image');
    this.thumbContainer = imageContainer.querySelector('.thumb');

    this.button.addEventListener('click', () => {
      if (this.button.classList.contains('active')) {
        this.button.classList.remove('active');
        this.thumbContainer.classList.remove('gravity-control');
        this.thumbContainer.querySelector('a').style = '';
        this.removeGravitySelectors();
      } else {
        this.button.classList.add('active');
        this.thumbContainer.classList.toggle('gravity-control');
        this.thumbContainer.querySelector('a').style.cursor = 'default';
        this.thumbContainer.querySelector('a').style.pointerEvents = 'none';
        for (const position in positions) {
          this.createGravitySelector(position);
        }
      }
    });
  }

  createGravitySelector(position) {
    const gravitySelector = document.createElement('div');
    gravitySelector.innerHTML = `<i class="fa ${positions[position].iconClass}" aria-hidden="true"></i>`;
    gravitySelector.classList.add('gravity-icon');
    gravitySelector.style.top = positions[position].top;
    gravitySelector.style.left = positions[position].left;
    gravitySelector.style.right = positions[position].right;
    gravitySelector.style.bottom = positions[position].bottom;
    if (positions[position].transform) {
      gravitySelector.style.transform = positions[position].transform;
    }
    if (positions[position].rotate) {
      gravitySelector.style.transform += ` rotate(${positions[position].rotate})`;
    }
    gravitySelector.setAttribute('tabindex', '0');
    this.gravitySelecorIcons.push(gravitySelector);
    gravitySelector.addEventListener('mouseenter', e => {
      this.gravitySelecorIcons.forEach(icon => {
        if (icon != e.target) {
          icon.setAttribute('data-hide', 'true');
        } else {
          icon.setAttribute('data-pale', 'true');
        }
      });

      this.thumbContainer.appendChild(this.createPreviewBox(position));
    });

    gravitySelector.addEventListener('mouseleave', () => {
      this.thumbContainer.removeChild(this.thumbContainer.querySelector('#gravity-box'));
      this.gravitySelecorIcons.forEach(icon => {
        icon.removeAttribute('data-hide');
        icon.removeAttribute('data-pale');
      });
    });
    this.thumbContainer.appendChild(gravitySelector);
  }

  createPreviewBox(position) {
    const box = document.createElement('div');
    box.id = 'gravity-box';
    box.classList.add('gravity-box');
    const imageDimensions = this.thumbContainer.querySelector('img').getBoundingClientRect();
    const width = 0.8 * Math.min(imageDimensions.width, imageDimensions.height) + 'px';
    box.style.width = width;
    box.style.aspectRatio = '1/1';
    box.style.top = positions[position].top;
    box.style.left = positions[position].left;
    box.style.right = positions[position].right;
    box.style.bottom = positions[position].bottom;
    box.style.transform = positions[position].transform;
    return box;
  }

  removeGravitySelectors() {
    this.gravitySelecorIcons.forEach(icon => {
      this.thumbContainer.removeChild(icon);
    });
    this.gravitySelecorIcons = [];
  }
}

export default GravityUiSelector;
