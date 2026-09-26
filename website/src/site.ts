export const ICON_URL = new URL("../assets/notic-icon.svg", import.meta.url).href;
export const DOWNLOAD_URL = new URL("../downloads/Notic-1.0-macOS.dmg", import.meta.url).href;

export const VERSION = "1.0";
export const SITE_URL = "https://notic.yagyaraj.com";
export const CONTACT_URL = "mailto:hey@yagyaraj.com";
export const DEVELOPER_URL = "https://yagyaraj.com";

export const NAV_ITEMS = [
  { label: "Features", to: "/", hash: "features" },
  { label: "How it works", to: "/", hash: "how-it-works" },
  { label: "FAQ", to: "/", hash: "faq" },
  { label: "Release notes", to: "/release-notes" },
] as const;
