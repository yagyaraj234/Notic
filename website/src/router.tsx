import { Link, createRootRoute, createRoute, createRouter, type RouterHistory } from "@tanstack/react-router";
import App from "./App.jsx";
import { Footer, Header, SkipLink } from "./components/SiteChrome";
import PrivacyPage from "./PrivacyPage.jsx";
import ReleaseNotes from "./ReleaseNotes.jsx";

function NotFoundPage() {
  return (
    <div className="site-shell">
      <SkipLink />
      <Header />
      <main id="main" tabIndex={-1}>
        <section className="notes-hero" aria-labelledby="not-found-title">
          <p className="eyebrow">Error 404</p>
          <h1 id="not-found-title">Page not found.</h1>
          <p>The page may have moved, or the address may be incorrect.</p>
          <div className="notes-actions">
            <Link to="/" className="download-button">
              Back to Notic
            </Link>
          </div>
        </section>
      </main>
      <Footer />
    </div>
  );
}

const rootRoute = createRootRoute({ notFoundComponent: NotFoundPage });

const homeRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/",
  component: App,
});

const releaseNotesRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/release-notes",
  component: ReleaseNotes,
});

const privacyRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/privacy",
  component: PrivacyPage,
});

const routeTree = rootRoute.addChildren([homeRoute, releaseNotesRoute, privacyRoute]);

export function createAppRouter(history?: RouterHistory) {
  return createRouter({
    routeTree,
    defaultPreload: "intent",
    scrollRestoration: true,
    history,
  });
}

export const router = createAppRouter();

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}
