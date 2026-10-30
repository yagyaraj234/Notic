import { useEffect, useRef, useState } from "react";
import { Link } from "@tanstack/react-router";
import { ArrowDownToLine, Menu, X } from "lucide-react";
import { CONTACT_URL, DEVELOPER_URL, DOWNLOAD_URL, ICON_URL, NAV_ITEMS, VERSION } from "../site";

export function StructuredData({ data }: { data: unknown }) {
  return <script type="application/ld+json">{JSON.stringify(data)}</script>;
}

/** Every download button opens the one install dialog mounted by Header. */
const OPEN_INSTALL_DIALOG = "notic:open-install-dialog";
/** Matches `.showcase-dialog[data-closing]` in index.css. */
const DIALOG_EXIT_MS = 150;

export function DownloadButton({ className = "", compact = false }: { className?: string; compact?: boolean }) {
  return (
    <a
      href={DOWNLOAD_URL}
      download
      className={`download-button ${className}`}
      aria-label={`Download Notic ${VERSION} for macOS`}
      onClick={(event) => {
        // The href stays a real link, so it still downloads without JS or on a modified click.
        if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
        event.preventDefault();
        window.dispatchEvent(new Event(OPEN_INSTALL_DIALOG));
      }}
    >
      <span>{compact ? "Download" : "Download for macOS"}</span>
      <ArrowDownToLine size={18} strokeWidth={1.8} aria-hidden="true" />
    </a>
  );
}

function InstallDialog() {
  const dialogRef = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const open = () => dialogRef.current?.showModal();
    window.addEventListener(OPEN_INSTALL_DIALOG, open);
    return () => window.removeEventListener(OPEN_INSTALL_DIALOG, open);
  }, []);

  /** Same exit as the showcase sheet: WebKit cannot transition `overlay`. */
  const close = () => {
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

  return (
    <dialog
      ref={dialogRef}
      className="showcase-dialog install-dialog"
      aria-labelledby="install-dialog-title"
      aria-describedby="install-dialog-lede"
      onCancel={(event) => {
        event.preventDefault();
        close();
      }}
      onClick={(event) => {
        if (event.target === dialogRef.current) close();
      }}
    >
      <div className="install-sheet">
        <button type="button" className="sheet-close" onClick={close} aria-label="Close">
          <X size={18} strokeWidth={1.8} aria-hidden="true" />
        </button>
        <span className="install-icon">
          <img src={ICON_URL} alt="" />
        </span>
        <h2 id="install-dialog-title">Almost there!</h2>
        <p id="install-dialog-lede" className="install-lede">
          Notic isn't notarized by Apple yet, so macOS may block it the first time you open it. Here's how to get past
          that:
        </p>

        <ol className="install-steps">
          <li>
            Open the downloaded <strong>.dmg</strong> and drag Notic into Applications.
          </li>
          <li>
            Open Notic. macOS says it can't check Notic for malicious software. Click <strong>Done</strong>.
          </li>
          <li>
            Go to System Settings › Privacy &amp; Security, scroll down, and click <strong>Open Anyway</strong> next to
            Notic. Confirm with your password.
          </li>
        </ol>

        <p className="install-note">You only do this once. Notic launches normally from then on.</p>

        <a href={DOWNLOAD_URL} download className="download-button install-download" onClick={close}>
          <span>Got it, download now</span>
          <ArrowDownToLine size={18} strokeWidth={1.8} aria-hidden="true" />
        </a>
      </div>
    </dialog>
  );
}

function NavLink({ item, onClick }: { item: (typeof NAV_ITEMS)[number]; onClick?: () => void }) {
  return (
    <Link to={item.to} hash={"hash" in item ? item.hash : undefined} onClick={onClick}>
      {item.label}
    </Link>
  );
}

export function Header() {
  const [menuOpen, setMenuOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header className="site-header" data-scrolled={scrolled}>
      <div className="header-inner">
        <Link to="/" className="brand" aria-label="Notic home">
          <span className="brand-mark">
            <img src={ICON_URL} alt="" />
          </span>
          Notic
        </Link>

        <nav className="desktop-nav" aria-label="Main navigation">
          {NAV_ITEMS.map((item) => (
            <NavLink key={item.label} item={item} />
          ))}
        </nav>

        <div className="header-actions">
          <DownloadButton compact className="header-download" />
          <button
            type="button"
            className="menu-button"
            aria-label={menuOpen ? "Close navigation" : "Open navigation"}
            aria-expanded={menuOpen}
            aria-controls="mobile-navigation"
            onClick={() => setMenuOpen((open) => !open)}
          >
            {menuOpen ? <X size={20} strokeWidth={1.8} /> : <Menu size={20} strokeWidth={1.8} />}
          </button>
        </div>

        <nav
          id="mobile-navigation"
          className="mobile-nav"
          aria-label="Mobile navigation"
          data-open={menuOpen ? "" : undefined}
          inert={!menuOpen}
        >
          {NAV_ITEMS.map((item) => (
            <NavLink key={item.label} item={item} onClick={() => setMenuOpen(false)} />
          ))}
          <DownloadButton />
        </nav>
      </div>
      <InstallDialog />
    </header>
  );
}

export function Footer() {
  return (
    <footer className="site-footer section-wrap">
      <Link to="/" className="brand" aria-label="Notic home">
        <span className="brand-mark">
          <img src={ICON_URL} alt="" />
        </span>
        Notic
      </Link>
      <p>Sticky notes at the edge of your Mac.</p>
      <div className="footer-links">
        <Link to="/release-notes">Release notes</Link>
        <Link to="/privacy">Privacy</Link>
        <Link to="/" hash="faq">
          FAQ
        </Link>
        <a href={CONTACT_URL}>Contact</a>
        <a href={DEVELOPER_URL} target="_blank" rel="noreferrer">
          Developer
        </a>
      </div>
    </footer>
  );
}

export function SkipLink() {
  return (
    <a href="#main" className="skip-link">
      Skip to content
    </a>
  );
}
