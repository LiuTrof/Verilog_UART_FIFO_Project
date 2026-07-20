import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    allowedHosts: [".free.pinggy.net", ".run.pinggy-free.link", ".serveousercontent.com"],
    proxy: {
      "/api": "http://127.0.0.1:8000"
    }
  }
});
