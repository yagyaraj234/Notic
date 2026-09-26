import { ArrowLeft } from "lucide-react";
import { DownloadButton, Footer, Header, SkipLink, StructuredData } from "./components/SiteChrome";
import { useScrollReveal } from "./hooks/useScrollReveal.js";
import { SITE_URL, VERSION } from "./site";

const PRIVACY_SCHEMA = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "WebPage",
      "@id": `${SITE_URL}/privacy/#page`,
      url: `${SITE_URL}/privacy/`,
      name: "Notic privacy",
      description: "How Notic stores notes, which permissions it avoids, and why it never uses the network.",
      inLanguage: "en",
      dateModified: "2026-09-24",
      isPartOf: { "@id": `${SITE_URL}/#website` },
      about: { "@id": `${SITE_URL}/#software` },
    },
    {
      "@type": "BreadcrumbList",
      itemListElement: [
        { "@type": "ListItem", position: 1, name: "Notic", item: `${SITE_URL}/` },
        { "@type": "ListItem", position: 2, name: "Privacy", item: `${SITE_URL}/privacy/` },
      ],
    },
  ],
};

export default function PrivacyPage() {
  useScrollReveal();

  return (
    <div className="site-shell">
      <StructuredData data={PRIVACY_SCHEMA} />
      <SkipLink />
      <Header />

      <main id="main" tabIndex={-1}>
        <section className="notes-hero" aria-labelledby="privacy-title">
          <p className="eyebrow">Privacy</p>
          <h1 id="privacy-title">Your notes stay local.</h1>
          <p>What Notic stores, where it keeps it, and the permissions it never asks for.</p>
          <div className="notes-actions">
            <DownloadButton />
          </div>
        </section>

        <article className="release-list privacy-list" data-reveal="">
          <div className="release-card">
            <div className="release-head">
              <h2>Notic {VERSION}</h2>
              <span className="release-meta">
                <time dateTime="2026-09-24">Updated September 24, 2026</time>
              </span>
            </div>
            <div className="release-body privacy-copy">
              <section>
                <h3>Local storage</h3>
                <p>
                  Notes, colours, sizes, and ordering are saved in a single local store inside Notic’s app sandbox.
                  There is no account, no cloud sync, and no collaboration. Notic runs no analytics, advertising,
                  crash-reporting SDK, or telemetry.
                </p>
              </section>
              <section>
                <h3>Permissions</h3>
                <p>
                  Notic does not request Accessibility, Screen Recording, Input Monitoring, camera, or microphone
                  permission. Global shortcuts use the system hot-key API, which needs none of them.
                </p>
              </section>
              <section>
                <h3>Network access</h3>
                <p>Notic makes no network requests. Every feature in version {VERSION} works fully offline.</p>
              </section>
              <section>
                <h3>Deleting your data</h3>
                <p>
                  Deleted notes are removed permanently after a ten-second undo window. Removing Notic and its sandbox
                  container deletes everything it stored.
                </p>
              </section>
              <section>
                <h3>Questions</h3>
                <p>
                  Email <a href="mailto:hey@yagyaraj.com">hey@yagyaraj.com</a> with privacy questions.
                </p>
              </section>
            </div>
          </div>
        </article>
      </main>

      <Footer />
    </div>
  );
}
