/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./pages/**/*.{js,jsx,ts,tsx}",
    "./components/**/*.{js,jsx,ts,tsx}"
  ],
  theme: {
    container: {
      center: true,
      padding: '1rem',
      screens: {
        DEFAULT: '100%',
        lg: '1280px',
      },
    },
    extend: {
      colors: {
        primary: '#1C1C1E', // charcoal header/footer
        surface: '#2A2A2E', // dark card background
        ink: '#0F0F10', // near black for text
        accent: '#FF6B2C', // Hands orange
        success: '#22C55E',
        warning: '#F59E0B',
      },
      fontFamily: {
        comfortaa: ["Comfortaa", "system-ui"],
      },
      boxShadow: {
        soft: '0 8px 24px rgba(0,0,0,0.08)',
        'xl-soft': '0 12px 30px rgba(0,0,0,0.12)',
      },
      borderRadius: {
        xl: '1rem',
        '2xl': '1.25rem',
      },
    },
  },
  plugins: [],
};
