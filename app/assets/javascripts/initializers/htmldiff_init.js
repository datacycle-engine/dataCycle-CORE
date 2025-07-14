import htmldiff from "../components/htmldiff.js";

export default function () {
  DataCycle.registerAddCallback(
    ".detail-type.string.has-changes.edit",
    "diff-content",
    diffContent.bind(this),
  );
}

function diffContent(textField) {
  const detailContent = textField.querySelector(".detail-content");

  if (!detailContent) return;

  detailContent.innerHTML = htmldiff(
    textField.dataset.diffBefore,
    textField.dataset.diffAfter,
  );
}
