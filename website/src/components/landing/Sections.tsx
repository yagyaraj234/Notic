import {
  ArrowRight,
  BookOpenText,
  CalendarDays,
  Check,
  ClipboardList,
  Link2,
  ListTodo,
  MessagesSquare,
  PhoneCall,
  Presentation,
} from "lucide-react";
import { Link } from "@tanstack/react-router";
import { DownloadButton } from "../SiteChrome";
import { EdgeDemo, RestingPill } from "./EdgeDemo.jsx";
import { CONTACT_URL, ICON_URL, VERSION } from "../../site";

export const FAQS = [
  [
    "Does Notic need an account or the internet?",
    "No. Notic has no account, no cloud sync, and makes no network requests. Notes are saved in a local store inside the app’s sandbox on your Mac.",
  ],
  [
    "Will hovering over the deck steal focus from my app?",
    "No. The pill and the fanned deck never take keyboard focus, so you can peek at your notes mid-sentence. Notic only becomes active when you click into a note to type.",
  ],
  [
    "Which permissions does Notic ask for?",
    "None. Global shortcuts use the system hot-key API, so Notic never asks for Accessibility, Screen Recording, or Input Monitoring access.",
  ],
  [
    "Can I move the deck to another edge?",
    "Yes. Choose Right, Left, or Bottom in Settings, or drag the pill or stack to any edge. Notic remembers the position after relaunch.",
  ],
  [
    "What happens if I delete a note by accident?",
    "Every delete gives you ten seconds to undo, and the countdown survives a relaunch. Archiving never deletes anything, so you can restore archived notes whenever you like.",
  ],
  [
    "How do I install Notic?",
    "Open the downloaded DMG and drag Notic into Applications. It runs on macOS 14 or later. The first time, right-click the app and choose Open, or allow it in System Settings › Privacy & Security.",
  ],
];

export function HeroSection() {
  return (
    <section className="hero" aria-labelledby="hero-title">
      <div className="hero-glow" aria-hidden="true" />

      <div className="hero-copy">
        <h1 id="hero-title">
          Your notes, one <span className="hero-mark">hover</span> away.
        </h1>
        <p className="hero-lede">
          Notic tucks sticky notes and to-dos into the edge of every display. Hover to fan them out, click to write, and
          get straight back to work. Everything stays on your Mac.
        </p>
        <div className="hero-actions">
          <DownloadButton />
          <Link to="/" hash="how-it-works" className="text-link">
            See how it works <ArrowRight size={17} strokeWidth={1.8} aria-hidden="true" />
          </Link>
        </div>
        <p className="system-note">
          <Check size={15} strokeWidth={1.8} aria-hidden="true" /> Version {VERSION} · macOS 14 or later · Free
        </p>
      </div>

      <div className="hero-art">
        <EdgeDemo autoplay />
      </div>
      <p className="compare-note">Try it: hover the dashes on the right edge, then click a tab.</p>
    </section>
  );
}

const PERFECT_FOR = [
  [ListTodo, "Daily to-dos"],
  [MessagesSquare, "Meeting jots"],
  [ClipboardList, "Snippets"],
  [Link2, "Links & numbers"],
  [CalendarDays, "Weekly plans"],
] as const;

export function PerfectForSection() {
  return (
    <section className="perfect-for" aria-labelledby="perfect-for-title" data-reveal="">
      <div className="perfect-for-inner section-wrap">
        <h2 id="perfect-for-title">Perfect for</h2>
        <ul>
          {PERFECT_FOR.map(([Icon, label]) => (
            <li key={label}>
              <Icon size={21} strokeWidth={1.7} aria-hidden="true" />
              <span>{label}</span>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

const USE_CASES = [
  [
    MessagesSquare,
    "Stand-ups and meetings",
    "Jot the action items while someone is still talking, without leaving the call window.",
  ],
  [Presentation, "Deep work", "Keep today’s three priorities one hover away, not buried behind a full notes app."],
  [PhoneCall, "Calls and support", "Park an order number, an address, or a follow-up and find it again in seconds."],
  [
    BookOpenText,
    "Reading and research",
    "Collect quotes and loose ideas as you go, then archive the note when the thought is done.",
  ],
] as const;

export function UseCasesSection() {
  return (
    <section className="use-cases section-wrap" aria-labelledby="use-cases-title">
      <div className="use-cases-heading" data-reveal="">
        <p className="eyebrow">Built for the in-between</p>
        <h2 id="use-cases-title">Less tab‑hunting. More doing.</h2>
      </div>
      <div className="use-case-grid">
        {USE_CASES.map(([Icon, title, copy], index) => (
          <article key={title} data-reveal="">
            <Icon size={22} strokeWidth={1.7} aria-hidden="true" />
            <div>
              <h3>{title}</h3>
              <p>{copy}</p>
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}

const MENU_ITEMS = [
  ["New Note", "⌥⌘N"],
  ["All Notes", "⌥⌘L"],
  ["Archive", "⌥⌘A"],
  ["Hide Notic", "⌃⌥⌘H"],
] as const;

export function WorkflowSection() {
  return (
    <section id="how-it-works" className="workflow" aria-labelledby="workflow-title">
      <div className="workflow-inner section-wrap">
        <div className="workflow-copy" data-reveal="">
          <p className="eyebrow">How it works</p>
          <h2 id="workflow-title">Press a shortcut and start typing.</h2>
          <ol className="steps">
            <li>
              <span>1</span>
              <div>
                <h3>Capture from anywhere</h3>
                <p>Press ⌥⌘N in any app. A fresh note opens, ready for your first line.</p>
              </div>
            </li>
            <li>
              <span>2</span>
              <div>
                <h3>Let it rest at the edge</h3>
                <p>Notes collapse into a slim row of coloured dashes. Hover whenever you need them.</p>
              </div>
            </li>
            <li>
              <span>3</span>
              <div>
                <h3>Archive when it’s done</h3>
                <p>Finished notes leave the deck but stay searchable in the library.</p>
              </div>
            </li>
          </ol>
        </div>

        <div className="menu-card" data-reveal="">
          <div className="menu-visual" aria-hidden="true">
            <div className="menu-bar">
              <span className="menu-bar-right">
                <span className="nx-status menu-status" />
                <i className="tabular">9:41</i>
              </span>
            </div>
            <div className="menu-dropdown">
              {MENU_ITEMS.map(([label, shortcut], index) => (
                <div key={label} className={`menu-item${index === 0 ? " is-hover" : ""}`}>
                  <span>{label}</span>
                  <kbd>{shortcut}</kbd>
                </div>
              ))}
              <hr />
              <div className="menu-item">
                <span>Settings…</span>
                <kbd>⌘,</kbd>
              </div>
              <div className="menu-item">
                <span>Quit Notic</span>
                <kbd>⌘Q</kbd>
              </div>
            </div>
            <RestingPill className="menu-edge-pill" colors={["yellow", "coral", "mint", "blue", "lavender"]} />
          </div>
          <div className="capture-note">
            <span className="note-icon">
              <Check size={16} strokeWidth={1.8} />
            </span>
            <div>
              <strong>No permissions to grant</strong>
              <p>
                Shortcuts use the system hot-key API, so Notic works without Accessibility, Screen Recording, or Input
                Monitoring access.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

export function PromiseSection() {
  return (
    <section className="promise section-wrap" aria-labelledby="promise-title" data-reveal="">
      <span className="promise-orb promise-orb-one" aria-hidden="true" />
      <span className="promise-orb promise-orb-two" aria-hidden="true" />
      <div className="promise-mark" aria-hidden="true">
        <img src={ICON_URL} alt="" />
      </div>
      <p className="eyebrow">Privacy</p>
      <h2 id="promise-title">Your notes never leave your Mac.</h2>
      <p>No account, no network, no telemetry. Notes live in a local store inside Notic’s sandbox and nowhere else.</p>
      <Link to="/privacy" className="text-link">
        Read the privacy details <ArrowRight size={17} strokeWidth={1.8} aria-hidden="true" />
      </Link>
    </section>
  );
}

export function FaqSection() {
  return (
    <section id="faq" className="faq section-wrap" aria-labelledby="faq-title">
      <div className="faq-heading" data-reveal="">
        <h2 id="faq-title">
          Questions?
          <span>Answered.</span>
        </h2>
      </div>
      <div className="faq-list">
        {FAQS.map(([question, answer]) => (
          <details key={question} name="faq">
            <summary>
              {question}
              <span className="faq-marker" aria-hidden="true" />
            </summary>
            <p>{answer}</p>
          </details>
        ))}
      </div>
      <p className="faq-more">
        Still stuck?{" "}
        <a href={CONTACT_URL}>
          Contact the developer <ArrowRight size={14} strokeWidth={1.8} aria-hidden="true" />
        </a>
      </p>
    </section>
  );
}

export function FinalCtaSection() {
  return (
    <section className="final-cta section-wrap" aria-labelledby="cta-title" data-reveal="">
      <div className="cta-glow" aria-hidden="true" />
      <div className="cta-notes" aria-hidden="true">
        <span data-color="coral" />
        <span data-color="mint" />
        <span data-color="lavender" />
      </div>
      <h2 id="cta-title">
        Give every thought a place.
        <span className="cta-mark">
          <img src={ICON_URL} alt="" />
        </span>
      </h2>
      <p className="cta-lede">Keep your next to-do where you can actually see it.</p>
      <DownloadButton />
      <ul className="cta-meta">
        <li className="tabular">Version {VERSION}</li>
        <li>macOS 14 or later</li>
        <li>Free</li>
      </ul>
    </section>
  );
}
