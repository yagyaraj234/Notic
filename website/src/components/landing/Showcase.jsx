import { useEffect, useRef, useState } from "react";
import { ArrowLeft, ArrowRight, X } from "lucide-react";
import { RestingPill } from "./EdgeDemo.jsx";

/** Matches `.showcase-dialog[data-closing]` in index.css. */
const DIALOG_EXIT_MS = 150;

const EDGE_COLORS = ["yellow", "coral", "mint", "blue"];

const SWATCHES = [
  ["yellow", "Yellow"],
  ["coral", "Coral"],
  ["mint", "Mint"],
  ["blue", "Blue"],
  ["lavender", "Lavender"],
  ["peach", "Peach"],
  ["sage", "Sage"],
  ["rose", "Rose"],
];

const SHOWCASE = [
  {
    key: "colors",
    label: "Colours",
    title: "Eight pastels, readable in every light.",
    copy: "Give each note its own colour so you can find it at a glance, even as a dash on the edge.",
    detail:
      "The paper stays light in dark mode by default, with dark ink on top. Prefer darker paper that matches your appearance? Switch it in Settings › Paper, and turn the tab lean off there too.",
    visual: (
      <div className="shot shot-colors">
        {SWATCHES.map(([color, name], index) => (
          <span key={color} data-color={color} style={{ "--i": index }}>
            {name}
          </span>
        ))}
      </div>
    ),
  },
  {
    key: "todos",
    label: "To-dos",
    title: "Type [] and it becomes a checkbox.",
    copy: "Turn any line into a task as you type, then tick it off with a click or a shortcut.",
    detail: (
      <>
        Start a line with <code className="syntax">[]</code> and a space, or press ⇧⌘T for Add to-do. Click the box or
        press ⌘Return on the line to mark it done. Every task is an accessible checkbox with its label and state.
      </>
    ),
    visual: (
      <div className="shot shot-todos">
        <div className="todo-typed">
          <code>[] </code>
          <span>becomes</span>
          <i />
        </div>
        <ul>
          <li className="is-done">
            <i />
            Renew passport
          </li>
          <li>
            <i />
            Email the landlord
          </li>
          <li>
            <i />
            Water the plants
          </li>
        </ul>
        <div className="todo-keys">
          <kbd>⇧⌘T</kbd>
          <kbd>⌘↩</kbd>
        </div>
      </div>
    ),
  },
  {
    key: "library",
    label: "Library",
    title: "Every note, one search away.",
    copy: "A two-pane library holds everything: active notes, archived notes, and all their text.",
    detail:
      "Search titles and bodies, filter active or archived notes, and archive, restore, or delete in bulk. Open it from the menu bar or with ⌥⌘L, then use the arrow keys and Return from the keyboard.",
    visual: (
      <div className="shot shot-library">
        <div className="library-list">
          <div className="library-search">Search notes</div>
          {[
            ["yellow", "Friday", true],
            ["mint", "Ideas", false],
            ["coral", "Standup", false],
            ["blue", "Reading", false],
          ].map(([color, name, active]) => (
            <div key={name} className={`library-row${active ? " is-active" : ""}`}>
              <i data-color={color} />
              {name}
            </div>
          ))}
        </div>
        <div className="library-detail" data-color="yellow">
          <strong>Friday</strong>
          <i style={{ width: "86%" }} />
          <i style={{ width: "64%" }} />
          <i style={{ width: "74%" }} />
        </div>
      </div>
    ),
  },
  {
    key: "edges",
    label: "Any edge",
    title: "Dock it right, left, or along the bottom.",
    copy: "Put the deck where your pointer already goes, on every display you use.",
    detail:
      "Pick Right, Left, or Bottom in Settings › General › Deck, or drag the pill or the stack to move it. Notic remembers the position after relaunch and keeps it inside the visible screen when displays change.",
    visual: (
      <div className="shot shot-edges">
        <div className="edges-screen">
          <RestingPill className="edge-pill edge-right" colors={EDGE_COLORS} />
          <RestingPill className="edge-pill edge-left" colors={EDGE_COLORS} />
          <RestingPill className="edge-pill edge-bottom" colors={EDGE_COLORS} />
        </div>
        <div className="edges-segment">
          <span>Left</span>
          <span className="is-on">Right</span>
          <span>Bottom</span>
        </div>
      </div>
    ),
  },
  {
    key: "fonts",
    label: "Fonts",
    title: "Handwritten by default. Yours to change.",
    copy: "Notes open in Patrick Hand. Switch to a font that suits your eyes, with a live preview.",
    detail:
      "Choose Patrick Hand, System font, Chalkboard, Marker Felt, Georgia, or Menlo in Settings › General › Notes. The editor supports larger text for comfortable reading.",
    visual: (
      <div className="shot shot-fonts">
        {[
          ["hand", "Patrick Hand"],
          ["system", "System font"],
          ["georgia", "Georgia"],
          ["menlo", "Menlo"],
        ].map(([font, name]) => (
          <div key={font} className="font-row" data-font={font}>
            <span>Buy oat milk</span>
            <small>{name}</small>
          </div>
        ))}
      </div>
    ),
  },
  {
    key: "undo",
    label: "Undo delete",
    title: "Ten seconds to change your mind.",
    copy: "Deleted a note by mistake? Undo it before the countdown runs out.",
    detail:
      "Deletion waits ten seconds before it becomes permanent, and that countdown survives an unexpected relaunch. Archiving never deletes, so archived notes stay until you remove them.",
    visual: (
      <div className="shot shot-undo">
        <div className="undo-note" data-color="rose">
          <strong>Gift ideas</strong>
          <i style={{ width: "72%" }} />
          <i style={{ width: "54%" }} />
        </div>
        <div className="undo-toast">
          <span className="undo-ring">
            <b className="tabular">8</b>
          </span>
          <span>Note deleted</span>
          <strong>Undo</strong>
        </div>
      </div>
    ),
  },
];

export function Showcase() {
  const trackRef = useRef(null);
  const dialogRef = useRef(null);
  const [atStart, setAtStart] = useState(true);
  const [atEnd, setAtEnd] = useState(false);
  const [scrollable, setScrollable] = useState(false);
  const [open, setOpen] = useState(null);

  useEffect(() => {
    if (open) dialogRef.current?.showModal();
  }, [open]);

  /** WebKit cannot transition `overlay`, so the exit is played here and the
   *  dialog is closed after it, rather than relying on allow-discrete alone. */
  const closeDialog = () => {
    const dialog = dialogRef.current;
    if (!dialog?.open || dialog.dataset.closing) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      dialog.close();
      return;
    }
    dialog.dataset.closing = "true";
    setTimeout(() => {
      delete dialog.dataset.closing;
      dialog.close();
    }, DIALOG_EXIT_MS);
  };

  const sync = () => {
    const track = trackRef.current;
    if (!track) return;
    setAtStart(track.scrollLeft < 8);
    setAtEnd(track.scrollLeft + track.clientWidth >= track.scrollWidth - 8);
    setScrollable(track.scrollWidth > track.clientWidth + 8);
  };

  useEffect(() => {
    sync();
    window.addEventListener("resize", sync);
    return () => window.removeEventListener("resize", sync);
  }, []);

  const step = (direction) => {
    const track = trackRef.current;
    const card = track?.firstElementChild;
    if (!card) return;
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    track.scrollBy({
      left: direction * (card.clientWidth + 24),
      behavior: reduced ? "auto" : "smooth",
    });
  };

  return (
    <section className="showcase" aria-labelledby="showcase-title">
      <div className="showcase-head section-wrap" data-reveal="">
        <div className="showcase-heading-copy">
          <p className="eyebrow">Details</p>
          <h2 id="showcase-title">Small app. Thoughtful details.</h2>
          <p className="showcase-lede">
            Colours, to-dos, a searchable library, and more. Open a card for the specifics.
          </p>
        </div>
        <div className="showcase-nav" hidden={!scrollable}>
          <button type="button" onClick={() => step(-1)} disabled={atStart} aria-label="Previous">
            <ArrowLeft size={18} strokeWidth={1.8} aria-hidden="true" />
          </button>
          <button type="button" onClick={() => step(1)} disabled={atEnd} aria-label="Next">
            <ArrowRight size={18} strokeWidth={1.8} aria-hidden="true" />
          </button>
        </div>
      </div>

      <div
        className="showcase-track"
        ref={trackRef}
        onScroll={sync}
        tabIndex={0}
        role="group"
        aria-label="Notic feature details"
      >
        {SHOWCASE.map((item, index) => (
          <button
            key={item.key}
            type="button"
            className="showcase-card"
            data-tone={item.key}
            data-reveal=""
            onClick={() => setOpen(item)}
            aria-label={`Read more about ${item.title}`}
          >
            <div className="showcase-visual" aria-hidden="true">
              {item.visual}
            </div>
            <div className="showcase-caption">
              <span className="showcase-label">{item.label}</span>
              <span className="showcase-card-title">{item.title}</span>
            </div>
          </button>
        ))}
      </div>

      <dialog
        ref={dialogRef}
        className="showcase-dialog"
        aria-labelledby={open ? "showcase-dialog-title" : undefined}
        onClose={() => setOpen(null)}
        onCancel={(event) => {
          event.preventDefault();
          closeDialog();
        }}
        onClick={(event) => {
          if (event.target === dialogRef.current) closeDialog();
        }}
      >
        {open && (
          <div className="showcase-sheet">
            <button type="button" className="sheet-close" onClick={closeDialog} aria-label="Close">
              <X size={18} strokeWidth={1.8} aria-hidden="true" />
            </button>
            <div className="showcase-visual" aria-hidden="true">
              {open.visual}
            </div>
            <div className="sheet-copy">
              <span className="showcase-label">{open.label}</span>
              <h3 id="showcase-dialog-title">{open.title}</h3>
              <p>{open.copy}</p>
              <p>{open.detail}</p>
            </div>
          </div>
        )}
      </dialog>
    </section>
  );
}
