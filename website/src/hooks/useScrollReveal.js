import { useEffect } from "react";

const STAGGER = 60;

/** Fades sections in once as they scroll into view. Decoration only.
 *  Items that arrive together stagger by their order in that batch, so a card
 *  reached later (down the page, along the carousel) never waits on its index.
 *  Once the fade ends the element is marked settled, which hands its own
 *  hover and press transitions back to it. */
export function useScrollReveal() {
  useEffect(() => {
    const targets = document.querySelectorAll("[data-reveal]");
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      targets.forEach((node) => node.classList.add("is-in", "is-settled"));
      return;
    }

    const settle = (event) => {
      const node = event.currentTarget;
      if (event.target !== node || event.propertyName !== "opacity") return;
      node.style.transitionDelay = "";
      node.classList.add("is-settled");
      node.removeEventListener("transitionend", settle);
      node.removeEventListener("transitioncancel", settle);
    };

    const observer = new IntersectionObserver(
      (entries) => {
        entries
          .filter((entry) => entry.isIntersecting)
          .forEach((entry, index) => {
            const node = entry.target;
            node.style.transitionDelay = `${index * STAGGER}ms`;
            node.addEventListener("transitionend", settle);
            node.addEventListener("transitioncancel", settle);
            node.classList.add("is-in");
            observer.unobserve(node);
          });
      },
      { rootMargin: "0px 0px -12% 0px" },
    );

    targets.forEach((node) => observer.observe(node));
    return () => observer.disconnect();
  }, []);
}
