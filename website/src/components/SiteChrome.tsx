import { useEffect, useState } from "react";
import { Link } from "@tanstack/react-router";
import { ArrowDownToLine, Menu, X } from "lucide-react";
import { CONTACT_URL, DEVELOPER_URL, DOWNLOAD_URL, ICON_URL, NAV_ITEMS } from "../site";

export function StructuredData({ data }: { data: unknown }) {
  return <script type="application/ld+json">{JSON.stringify(data)}</script>;
}

export function DownloadButton({ className = "", compact = false }: { className?: string; compact?: boolean }) {
  return (
    <a
      href={DOWNLOAD_URL}
      download
      className={`download-button ${className}`}
      aria-label="Download Notic 1.0 for macOS"
    >
      <span>{compact ? "Download" : "Download for macOS"}</span>
      <ArrowDownToLine size={18} strokeWidth={1.8} aria-hidden="true" />
    </a>
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
