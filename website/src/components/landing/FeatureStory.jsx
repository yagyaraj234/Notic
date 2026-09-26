import { useEffect, useRef, useState } from "react";
import { Layers, PanelRight, PenLine } from "lucide-react";
import { EdgeDemo } from "./EdgeDemo.jsx";

const STORIES = [
  {
    icon: PanelRight,
    label: "Rest",
    title: "Out of sight, never out of reach.",
    copy: "At rest, your notes shrink to a slim row of coloured dashes on the edge of every display. No windows to shuffle, no Dock icon.",
    visual: <EdgeDemo className="nx-compact" stageHeight={640} />,
  },
  {
    icon: Layers,
    label: "Fan",
    title: "Hover, and your deck fans out.",
    copy: "Notes shingle down the edge as colour tabs, each with its own label and a slight lean. Your app keeps focus the whole time.",
    visual: <EdgeDemo className="nx-compact" stageHeight={640} initial={{ fanned: true }} />,
  },
  {
    icon: PenLine,
    label: "Write",
    title: "Click a tab. Start writing.",
    copy: (
      <>
        The note slides out level with its tab. Type <code className="syntax">[]</code> for a to-do, tick it off, and
        Notic saves as you go.
      </>
    ),
    visual: <EdgeDemo className="nx-compact" stageHeight={640} initial={{ open: 2 }} />,
  },
];

export function FeatureStory() {
  const markers = useRef([]);
  const [active, setActive] = useState(0);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        const current = entries.find((entry) => entry.isIntersecting);
        if (current) setActive(Number(current.target.dataset.story));
      },
      { rootMargin: "-46% 0px -46% 0px" },
    );

    markers.current.forEach((marker) => marker && observer.observe(marker));
    return () => observer.disconnect();
  }, []);

  const selectStory = (index) => {
    if (!window.matchMedia("(min-width: 901px)").matches) {
      setActive(index);
      return;
    }
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    markers.current[index]?.scrollIntoView({
      behavior: reduced ? "auto" : "smooth",
      block: "center",
    });
  };

  return (
    <section id="features" className="story" aria-labelledby="features-title">
      <div className="story-heading section-wrap" data-reveal="">
        <p className="eyebrow">Features</p>
        <h2 id="features-title">Always there. Never in the way.</h2>
      </div>

      <div className="story-scroll">
        <div className="story-pin section-wrap">
          <div className="story-canvas">
            <div className="story-nav" aria-label="Feature scenes">
              {STORIES.map(({ icon: Icon, label }, index) => (
                <button
                  key={label}
                  type="button"
                  className={active === index ? "is-active" : ""}
                  aria-pressed={active === index}
                  onClick={() => selectStory(index)}
                >
                  <Icon size={17} strokeWidth={1.8} aria-hidden="true" />
                  {label}
                </button>
              ))}
            </div>

            <div className="story-scenes">
              {STORIES.map((item, index) => (
                <article
                  key={item.label}
                  className={`story-scene story-scene-${index + 1}${active === index ? " is-active" : ""}`}
                  aria-hidden={active !== index}
                >
                  <div className="story-copy">
                    <p>{item.label}</p>
                    <h3>{item.title}</h3>
                    <span>{item.copy}</span>
                  </div>
                  <div className="story-visual" aria-hidden="true">
                    {item.visual}
                  </div>
                </article>
              ))}
            </div>
          </div>
        </div>

        <div className="story-markers" aria-hidden="true">
          {STORIES.map((item, index) => (
            <span
              key={item.label}
              ref={(node) => {
                markers.current[index] = node;
              }}
              data-story={index}
            />
          ))}
        </div>
      </div>
    </section>
  );
}
