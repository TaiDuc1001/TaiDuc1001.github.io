// Initialize medium zoom with adaptive orientation scaling (60-70% viewport).
$(document).ready(function () {
  function getAdaptiveMargin(img) {
    const vw = window.innerWidth;
    const vh = window.innerHeight;

    if (!img) {
      return Math.max(48, Math.round(Math.min(vw, vh) * 0.16));
    }

    const width = img.naturalWidth || img.width || vw;
    const height = img.naturalHeight || img.height || vh;
    const ratio = width / height;

    if (ratio < 0.9) {
      // Portrait / tall images: ~70% screen height fit with comfortable margins
      return Math.max(48, Math.round(vh * 0.15));
    } else {
      // Landscape / horizontal diagrams / squares: ~60-70% viewport
      return Math.max(48, Math.round(Math.min(vw, vh) * 0.16));
    }
  }

  medium_zoom = mediumZoom("[data-zoomable]", {
    background: getComputedStyle(document.documentElement).getPropertyValue("--global-bg-color") + "ee",
    margin: getAdaptiveMargin(null),
    scrollOffset: 40,
  });

  medium_zoom.on("open", function (event) {
    const target = event.target;
    if (target) {
      medium_zoom.update({ margin: getAdaptiveMargin(target) });
    }
  });

  window.addEventListener("resize", function () {
    if (medium_zoom) {
      medium_zoom.update({ margin: getAdaptiveMargin(null) });
    }
  });
});
