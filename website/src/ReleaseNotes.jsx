import { ArrowLeft, Check, Info } from "lucide-react";
import { DownloadButton, Footer, Header, SkipLink, StructuredData } from "./components/SiteChrome";
import { useScrollReveal } from "./hooks/useScrollReveal.js";
import { SITE_URL, VERSION } from "./site";

const RELEASE_NOTES_SCHEMA = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "CollectionPage",
      "@id": `${SITE_URL}/release-notes/#page`,
      url: `${SITE_URL}/release-notes/`,
      name: "Notic release notes",
      description: "Shipped Notic changes and system requirements.",
      inLanguage: "en",
      isPartOf: { "@id": `${SITE_URL}/#website` },
      about: { "@id": `${SITE_URL}/#software` },
    },
    {
      "@type": "BreadcrumbList",
      itemListElement: [
        { "@type": "ListItem", position: 1, name: "Notic", item: `${SITE_URL}/` },
        {
          "@type": "ListItem",
          position: 2,
          name: "Release notes",
          item: `${SITE_URL}/release-notes/`,
        },
      ],
    },
    {
      "@type": "SoftwareApplication",
      "@id": `${SITE_URL}/#software`,
      name: "Notic",
      operatingSystem: "macOS 14 or later",
      applicationCategory: "UtilitiesApplication",
      softwareVersion: VERSION,
    },
  ],
};

/** Only shipped builds belong here. */
const RELEASES = [
  {
    version: "1.0",
    meta: "First public build · macOS 14+",
    latest: true,
    changes: [
      "Edge deck on every display that rests as a row of coloured dashes and fans out on hover",
      "Dock the deck on the right, left, or bottom edge, or drag it into place",
      "Resizable plain-text editor that slides out beside its tab, with autosave",
      <>
        Checkbox to-dos with <code className="syntax">[]</code>, ⇧⌘T, and ⌘Return
      </>,
      "Eight pastel colours, optional adaptive paper, and six font choices",
      "Searchable two-pane library with archive, restore, and a ten-second undo for deletes",
      "Global shortcuts for new note, library, archive, and hide that need no extra permissions",
    ],
    caveat:
      "This build is not notarized yet. The first time you open it, right-click Notic and choose Open, or allow it in System Settings › Privacy & Security.",
  },
];

export default function ReleaseNotes() {
  useScrollReveal();

  return (
    <div className="site-shell">
      <StructuredData data={RELEASE_NOTES_SCHEMA} />
      <SkipLink />
      <Header />

      <main id="main" tabIndex={-1}>
        <section className="notes-hero" aria-labelledby="notes-title">
          <p className="eyebrow">What’s new</p>
          <h1 id="notes-title">Release notes</h1>
          <p>Read shipped changes and system requirements for each version.</p>
          <div className="notes-actions">
            <DownloadButton />
          </div>
        </section>

        <div className="release-list">
          {RELEASES.map((release, index) => (
            <article
              key={release.version}
              className="release-card"
              data-reveal=""
              aria-labelledby={`release-${release.version}`}
            >
              <div className="release-head">
                <h2 id={`release-${release.version}`}>Notic {release.version}</h2>
                {release.latest && <span className="pill">Latest</span>}
                <span className="release-meta">{release.meta}</span>
              </div>

              <div className="release-body">
                <h3>What’s included</h3>
                <ul>
                  {release.changes.map((change, index) => (
                    <li key={index}>
                      <Check size={15} strokeWidth={1.8} aria-hidden="true" />
                      <span>{change}</span>
                    </li>
                  ))}
                </ul>

                {release.caveat && (
                  <p className="release-callout">
                    <Info size={16} strokeWidth={1.8} aria-hidden="true" />
                    <span>{release.caveat}</span>
                  </p>
                )}
              </div>
            </article>
          ))}
        </div>
      </main>

      <Footer />
    </div>
  );
}
