import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  appType: "spa",
  plugins: [react(), tailwindcss()],
  build: {
    rollupOptions: {
      output: {
        assetFileNames(assetInfo) {
          const sourceName = assetInfo.names?.[0] ?? assetInfo.name ?? "";
          return sourceName.endsWith(".dmg") ? "downloads/[name][extname]" : "assets/[name]-[hash][extname]";
        },
      },
    },
  },
});
