import { Footer, Header, SkipLink, StructuredData } from "./components/SiteChrome";
import { FeatureStory } from "./components/landing/FeatureStory.jsx";
import {
  FAQS,
  FaqSection,
  FinalCtaSection,
  HeroSection,
  PerfectForSection,
  PromiseSection,
  UseCasesSection,
  WorkflowSection,
} from "./components/landing/Sections";
import { Showcase } from "./components/landing/Showcase.jsx";
import { useScrollReveal } from "./hooks/useScrollReveal.js";
import { DEVELOPER_URL, SITE_URL, VERSION } from "./site";

const HOME_SCHEMA = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "WebSite",
      "@id": `${SITE_URL}/#website`,
      url: `${SITE_URL}/`,
      name: "Notic",
      description: "Sticky notes and to-dos that live at the edge of your Mac's screen.",
      inLanguage: "en",
      publisher: { "@id": `${SITE_URL}/#creator` },
    },
    {
      "@type": "Person",
      "@id": `${SITE_URL}/#creator`,
      name: "Yagyaraj Lodhi",
      url: DEVELOPER_URL,
      sameAs: ["https://github.com/yagyaraj234"],
    },
    {
      "@type": "SoftwareApplication",
      "@id": `${SITE_URL}/#software`,
      name: "Notic",
      url: `${SITE_URL}/`,
      description:
        "A local-first macOS menu-bar app that keeps sticky notes and to-dos one hover away at the edge of every display.",
      applicationCategory: "UtilitiesApplication",
      applicationSubCategory: "Notes",
      operatingSystem: "macOS 14 or later",
      softwareVersion: VERSION,
      downloadUrl: `${SITE_URL}/downloads/Notic-1.0-macOS.dmg`,
      screenshot: `${SITE_URL}/assets/notic-icon.svg`,
      featureList: [
        "Edge-docked note deck on every display",
        "Hover to fan notes without stealing focus",
        "Checkbox to-dos with keyboard shortcuts",
        "Eight pastel note colours",
        "Searchable library with archive and restore",
        "Global shortcuts without extra permissions",
      ],
      offers: {
        "@type": "Offer",
        price: "0",
        priceCurrency: "USD",
        availability: "https://schema.org/InStock",
      },
      author: { "@id": `${SITE_URL}/#creator` },
    },
    {
      "@type": "FAQPage",
      "@id": `${SITE_URL}/#faq`,
      url: `${SITE_URL}/#faq`,
      inLanguage: "en",
      mainEntity: FAQS.map(([question, answer]) => ({
        "@type": "Question",
        name: question,
        acceptedAnswer: { "@type": "Answer", text: answer },
      })),
    },
  ],
};

export default function App() {
  useScrollReveal();

  return (
    <div className="site-shell">
      <StructuredData data={HOME_SCHEMA} />
      <SkipLink />
      <Header />
      <main id="main" tabIndex={-1}>
        <HeroSection />
        <PerfectForSection />
        <FeatureStory />
        <Showcase />
        <UseCasesSection />
        <WorkflowSection />
        <PromiseSection />
        <FaqSection />
        <FinalCtaSection />
      </main>
      <Footer />
    </div>
  );
}
