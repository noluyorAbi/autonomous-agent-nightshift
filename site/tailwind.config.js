/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        bg: {
          DEFAULT: "#0a0e1f",
          elevated: "#0f1530",
          card: "#131a3a",
          code: "#060a18",
        },
        border: {
          DEFAULT: "#1e2747",
          strong: "#2d3a6b",
        },
        fg: {
          DEFAULT: "#e6e8f0",
          muted: "#8b92b0",
          dim: "#5a6388",
        },
        accent: {
          DEFAULT: "#f59e0b",
          dim: "#b97804",
          glow: "rgba(245, 158, 11, 0.15)",
        },
        success: "#34d399",
        warning: "#fbbf24",
        danger: "#f87171",
      },
      fontFamily: {
        sans: [
          "-apple-system",
          "BlinkMacSystemFont",
          "Inter",
          "Segoe UI",
          "Roboto",
          "sans-serif",
        ],
        mono: [
          "JetBrains Mono",
          "SF Mono",
          "Monaco",
          "Consolas",
          "Liberation Mono",
          "monospace",
        ],
      },
      animation: {
        "fade-in": "fadeIn 600ms ease-out",
        "slide-up": "slideUp 500ms cubic-bezier(0.16, 1, 0.3, 1)",
        glow: "glow 3s ease-in-out infinite",
        "pulse-slow": "pulse 4s cubic-bezier(0.4, 0, 0.6, 1) infinite",
      },
      keyframes: {
        fadeIn: {
          "0%": { opacity: "0" },
          "100%": { opacity: "1" },
        },
        slideUp: {
          "0%": { opacity: "0", transform: "translateY(20px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        glow: {
          "0%, 100%": { opacity: "0.5" },
          "50%": { opacity: "1" },
        },
      },
    },
  },
  plugins: [],
};
