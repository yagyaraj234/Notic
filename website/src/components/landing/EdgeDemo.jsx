import { useCallback, useEffect, useRef, useState } from "react";
import { Check, ListChecks, Pin, Plus, Trash2, X } from "lucide-react";

/**
 * A faithful, interactive copy of Notic's edge surfaces, drawn in the app's
 * own point sizes (EdgeLayout.swift, DeckView.swift, EditorView.swift) and
 * scaled to fit with `--u` (one macOS point). Everything is anchored to the
 * stage's right edge, the same edge the real deck hangs from.
 */

// EdgeLayout
const PILL_WIDTH = 12;
const DASH_H = 22;
const DASH_GAP = 6;
const PILL_PAD = 7;
const TAB_W = 64;
const TAB_H = 128;
const TAB_STEP = 72;
const OVERHANG = 8;
const ADD_SIZE = 36;
const ADD_GAP = 14;
const DECK_PAD = 16;
const DECK_W = TAB_W + 40;
const MARGIN = 8;
const MENU_BAR = 24;
// Motion.swift / SPEC.md
const OPEN_DELAY = 120;
const CLOSE_DELAY = 350;

export const NOTE_COLORS = ["yellow", "coral", "mint", "blue", "lavender", "peach", "sage", "rose"];

export const DEMO_NOTES = [
  {
    title: "Friday",
    color: "yellow",
    lean: -1.6,
    body: [
      [true, "Send the deck to Priya"],
      [true, "Book the dentist"],
      [false, "Review Q4 numbers"],
      [false, "Pick up oat milk"],
      null,
      "Ask Sam about the launch date",
    ],
  },
  {
    title: "Standup",
    color: "coral",
    lean: 2.1,
    body: ["Blocked on the API review", null, [false, "Ping design about icons"], [false, "Demo the new deck"]],
  },
  {
    title: "Ideas",
    color: "mint",
    lean: -1.3,
    body: [
      [true, "Pill that lives on any edge"],
      [false, "Tabs that lean a little"],
      null,
      "Keep it tiny. Keep it local.",
    ],
  },
  {
    title: "Reading",
    color: "blue",
    lean: 2.4,
    body: ["Thinking in Systems, ch. 4", "The Design of Everyday Things", null, [false, "Return library books"]],
  },
  {
    title: "Call Mom",
    color: "lavender",
    lean: -1.8,
    body: ["Sunday after lunch", [false, "Ask about the trip photos"], [false, "Send the recipe"]],
  },
];

const u = (n) => `calc(${n} * var(--u))`;

function deckGeometry(count, stageH) {
  const tabsHeight = (count - 1) * TAB_STEP + TAB_H;
  const height = DECK_PAD * 2 + tabsHeight + ADD_GAP + ADD_SIZE;
  const center = MENU_BAR + (stageH - MENU_BAR) / 2;
  const top = center - height / 2;
  const pillH = PILL_PAD * 2 + count * DASH_H + (count - 1) * DASH_GAP;
  return { top, height, tabsHeight, center, pillH };
}

/** Where the editor opens: level with its tab, 8pt off the deck, kept on screen. */
function editorTop(index, deck, stageH, editorH) {
  const top = deck.top + DECK_PAD + index * TAB_STEP;
  return Math.max(MENU_BAR + MARGIN, Math.min(top, stageH - MARGIN - editorH));
}

function Pill({ notes, hovered }) {
  return (
    <span className="nx-pill" data-hovered={hovered || undefined}>
      {notes.map((note, index) => (
        <i key={index} data-color={note.color} />
      ))}
    </span>
  );
}

function Tab({ note, isOpen, hovered, pressed, isLast }) {
  const visible = isLast ? TAB_H : TAB_STEP;
  return (
    <span
      className="nx-tab"
      data-color={note.color}
      data-open={isOpen || undefined}
      data-hovered={hovered || undefined}
      data-pressed={pressed || undefined}
      style={{ "--lean": `${note.lean}deg` }}
    >
      <span className="nx-tab-label" style={{ height: u(Math.max(24, visible - 22)) }}>
        <b>{note.title.toUpperCase()}</b>
      </span>
      <span className="nx-tab-perf" />
    </span>
  );
}

function Line({ line, onToggle }) {
  if (line === null) return <p className="nx-line nx-blank" />;
  if (typeof line === "string") return <p className="nx-line">{line}</p>;
  const [done, text] = line;
  return (
    <p className="nx-line nx-task" data-done={done || undefined}>
      <button type="button" className="nx-box" tabIndex={-1} onClick={onToggle}>
        {done && <Check strokeWidth={4} />}
      </button>
      <span>{text}</span>
    </p>
  );
}

function Editor({ note, onClose, onToggle, caret }) {
  const tasks = note.body.filter((line) => Array.isArray(line));
  const done = tasks.filter(([isDone]) => isDone).length;
  return (
    <div className="nx-editor-surface" data-color={note.color}>
      <div className="nx-editor-head">
        <button type="button" className="nx-chrome" tabIndex={-1} onClick={onClose}>
          <X strokeWidth={2.6} />
        </button>
        <strong>{note.title}</strong>
        {tasks.length > 0 && (
          <small className="tabular">
            {done}/{tasks.length}
          </small>
        )}
        <span className="nx-spacer" />
        <span className="nx-chrome">
          <Pin strokeWidth={2.4} />
        </span>
      </div>
      <div className="nx-editor-rule" />
      <div className="nx-editor-body">
        {note.body.map((line, index) => (
          <Line key={index} line={line} onToggle={() => onToggle(index)} />
        ))}
        {caret && <span className="nx-caret" />}
      </div>
      <div className="nx-editor-foot">
        {NOTE_COLORS.map((color) => (
          <span
            key={color}
            className="nx-swatch"
            data-color={color}
            data-selected={color === note.color || undefined}
          />
        ))}
        <span className="nx-chrome">
          <ListChecks strokeWidth={2.4} />
        </span>
        <span className="nx-spacer" />
        <span className="nx-chrome nx-danger">
          <Trash2 strokeWidth={2.4} />
        </span>
      </div>
    </div>
  );
}

/**
 * @param {{
 *   notes?: typeof DEMO_NOTES,
 *   stageHeight?: number,
 *   editorSize?: [number, number],
 *   initial?: { fanned?: boolean, open?: number | null },
 *   interactive?: boolean,
 *   autoplay?: boolean,
 *   desk?: boolean,
 *   className?: string,
 * }} props
 */
export function EdgeDemo({
  notes: initialNotes = DEMO_NOTES,
  stageHeight = 820,
  editorSize = [580, 420],
  initial = {},
  interactive = true,
  autoplay = false,
  desk = true,
  className = "",
}) {
  const [notes, setNotes] = useState(initialNotes);
  const [fanned, setFanned] = useState(Boolean(initial.fanned || initial.open != null));
  const [open, setOpen] = useState(initial.open ?? null);
  const [shown, setShown] = useState(initial.open ?? null); // last opened, kept for the exit
  const [hoverTab, setHoverTab] = useState(-1);
  const [pressTab, setPressTab] = useState(-1);
  const [pillHover, setPillHover] = useState(false);
  const [cursor, setCursor] = useState(null); // autoplay pointer, in points from the right/top
  const [driving, setDriving] = useState(autoplay);
  const [glide, setGlide] = useState(false);

  const timer = useRef(0);
  const inside = useRef(false);
  const deck = deckGeometry(notes.length, stageHeight);
  const [editorW, editorH] = editorSize;

  const clear = () => window.clearTimeout(timer.current);
  const later = (fn, ms) => {
    clear();
    timer.current = window.setTimeout(fn, ms);
  };

  const openRef = useRef(open);
  openRef.current = open;

  const openNote = useCallback((index) => {
    // Like the app: the first open presents at once, moving between notes glides.
    setGlide(openRef.current != null && openRef.current !== index);
    setOpen(index);
    setShown(index);
    setFanned(true);
  }, []);

  const closeNote = useCallback(() => {
    setOpen(null);
    setGlide(false);
    if (!inside.current) window.setTimeout(() => !inside.current && setFanned(false), CLOSE_DELAY);
  }, []);

  const toggleTask = (noteIndex, lineIndex) => {
    setNotes((all) =>
      all.map((note, i) =>
        i !== noteIndex
          ? note
          : {
              ...note,
              body: note.body.map((line, j) => (j === lineIndex && Array.isArray(line) ? [!line[0], line[1]] : line)),
            },
      ),
    );
  };

  // Autoplay: a scripted pointer walks through rest → fan → open → switch → close.
  useEffect(() => {
    if (!driving) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setDriving(false);
      setFanned(true);
      setOpen(0);
      setShown(0);
      return;
    }
    const tabPoint = (i) => ({ right: 34, top: deck.top + DECK_PAD + i * TAB_STEP + 36 });
    const pillPoint = { right: 6, top: deck.center + 10 };
    const steps = [
      [900, () => setCursor({ right: 260, top: deck.center + 120 })],
      [900, () => setCursor(pillPoint)],
      [500, () => setPillHover(true)],
      [OPEN_DELAY + 40, () => (setPillHover(false), setFanned(true))],
      [650, () => setCursor(tabPoint(0))],
      [380, () => setHoverTab(0)],
      [300, () => setPressTab(0)],
      [120, () => (setPressTab(-1), setHoverTab(-1), openNote(0))],
      [2600, () => setCursor(tabPoint(2))],
      [420, () => setHoverTab(2)],
      [300, () => (setHoverTab(-1), openNote(2))],
      [
        2400,
        () => setCursor({ right: DECK_W + MARGIN + editorW - 26, top: editorTop(2, deck, stageHeight, editorH) + 22 }),
      ],
      [700, () => closeNote()],
      [200, () => setCursor({ right: 300, top: deck.center + 160 })],
      [CLOSE_DELAY, () => setFanned(false)],
      [2200, null],
    ];
    let cancelled = false;
    let handle = 0;
    let i = 0;
    const run = () => {
      if (cancelled) return;
      const [wait, action] = steps[i];
      handle = window.setTimeout(() => {
        if (cancelled) return;
        action?.();
        i = (i + 1) % steps.length;
        if (i === 0) setNotes(initialNotes);
        run();
      }, wait);
    };
    run();
    return () => {
      cancelled = true;
      window.clearTimeout(handle);
    };
  }, [driving]); // eslint-disable-line react-hooks/exhaustive-deps

  /** The visitor takes over from the scripted pointer the moment they move in. */
  const takeOver = () => {
    if (!driving) return;
    setDriving(false);
    setCursor(null);
    setPillHover(false);
    setHoverTab(-1);
    setPressTab(-1);
    // Hand back a resting deck unless the visitor is already on it.
    later(() => {
      if (inside.current) return;
      setOpen(null);
      setFanned(false);
    }, CLOSE_DELAY);
  };

  const onStageEnter = () => {
    if (interactive) takeOver();
  };

  const surfaceEnter = () => {
    inside.current = true;
    clear();
  };
  const surfaceLeave = () => {
    inside.current = false;
    setPillHover(false);
    setHoverTab(-1);
    if (open == null) later(() => setFanned(false), CLOSE_DELAY);
  };

  const events = interactive
    ? {
        pill: {
          onPointerEnter: () => {
            surfaceEnter();
            setPillHover(true);
            later(() => setFanned(true), OPEN_DELAY);
          },
          onPointerLeave: surfaceLeave,
          onClick: () => (clear(), setFanned(true)),
        },
        deck: { onPointerEnter: surfaceEnter, onPointerLeave: surfaceLeave },
        tab: (i) => ({
          onPointerEnter: () => setHoverTab(i),
          onPointerLeave: () => (setHoverTab(-1), setPressTab(-1)),
          onPointerDown: () => setPressTab(i),
          onPointerUp: () => (setPressTab(-1), openNote(i)),
        }),
        editor: { onPointerEnter: surfaceEnter, onPointerLeave: surfaceLeave },
      }
    : { pill: {}, deck: {}, tab: () => ({}), editor: {} };

  const note = shown != null ? notes[shown] : null;

  return (
    <div
      className={`nx-demo ${className}`}
      style={{ "--stage-h": stageHeight }}
      onPointerEnter={onStageEnter}
      data-fanned={fanned || undefined}
      data-open={open != null || undefined}
    >
      <div className="nx-stage" aria-hidden="true">
        {desk && (
          <>
            <div className="nx-menubar">
              <b>Slides</b>
              <i>File</i>
              <i>Edit</i>
              <i>View</i>
              <i>Play</i>
              <span className="nx-menubar-right">
                <span className="nx-status" />
                <i className="tabular">Fri 9:41</i>
              </span>
            </div>
            <div className="nx-window">
              <div className="nx-window-bar">
                <span />
                <span />
                <span />
                <small>Q4 roadmap</small>
              </div>
              <div className="nx-window-body">
                <div className="nx-slide">
                  <strong>Q4 roadmap</strong>
                  <i style={{ width: "58%" }} />
                  <i style={{ width: "42%" }} />
                  <div className="nx-chart">
                    <span style={{ height: "42%" }} />
                    <span style={{ height: "68%" }} />
                    <span style={{ height: "54%" }} />
                    <span style={{ height: "86%" }} />
                  </div>
                </div>
              </div>
            </div>
          </>
        )}

        <div
          className="nx-pill-hit"
          style={{ top: u(deck.center - deck.pillH / 2), height: u(deck.pillH) }}
          {...events.pill}
        >
          <Pill notes={notes} hovered={pillHover} />
        </div>

        <div className="nx-deck" style={{ top: u(deck.top), height: u(deck.height) }} {...events.deck}>
          <div className="nx-tabs" style={{ height: u(deck.tabsHeight) }}>
            {notes.map((n, i) => (
              <span key={n.title} className="nx-tab-hit" style={{ top: u(i * TAB_STEP), zIndex: i }} {...events.tab(i)}>
                <Tab
                  note={n}
                  isOpen={open === i}
                  hovered={hoverTab === i}
                  pressed={pressTab === i}
                  isLast={i === notes.length - 1}
                />
              </span>
            ))}
          </div>
          <span className="nx-add">
            <Plus strokeWidth={2} />
          </span>
        </div>

        {note && (
          <div
            className="nx-editor"
            data-visible={open != null || undefined}
            data-glide={glide || undefined}
            style={{
              right: u(DECK_W + MARGIN),
              width: u(editorW),
              height: u(editorH),
              transform: `translateY(${u(editorTop(shown, deck, stageHeight, editorH))})`,
            }}
            {...events.editor}
          >
            <Editor note={note} onClose={closeNote} onToggle={(line) => toggleTask(shown, line)} caret={open === 0} />
          </div>
        )}

        {cursor && (
          <span
            className="nx-cursor"
            data-pressing={pressTab >= 0 || undefined}
            style={{ transform: `translate(${u(-cursor.right)}, ${u(cursor.top)})` }}
          />
        )}
      </div>
    </div>
  );
}

/** The dormant pill on its own, for small illustrations. */
export function RestingPill({ colors = NOTE_COLORS.slice(0, 5), className = "" }) {
  return (
    <span className={`nx-pill ${className}`}>
      {colors.map((color, index) => (
        <i key={`${color}-${index}`} data-color={color} />
      ))}
    </span>
  );
}
