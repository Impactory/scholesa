/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ['class', '[data-theme="dark"]'],
  content: [
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './src/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        scholesa: {
          navy: '#0F2D4B',
          sky: '#0F96C3',
          teal: '#006969',
          emerald: '#1EA569',
          gold: '#F0C31E',
          orange: '#F0963C',
          coral: '#F0695A',
          page: '#F7FAFC',
          warm: '#F8FBF9',
          skySoft: '#E8F6FB',
          tealSoft: '#E5F3F3',
          emeraldSoft: '#EAF7F1',
          goldSoft: '#FFF7D6',
          orangeSoft: '#FFF0E3',
          coralSoft: '#FDECEA',
        },
        border: 'hsl(var(--border) / <alpha-value>)',
        input: 'hsl(var(--input) / <alpha-value>)',
        ring: 'hsl(var(--ring) / <alpha-value>)',
        background: 'hsl(var(--background) / <alpha-value>)',
        foreground: 'hsl(var(--foreground) / <alpha-value>)',
        primary: {
          DEFAULT: 'hsl(var(--primary) / <alpha-value>)',
          foreground: 'hsl(var(--primary-foreground) / <alpha-value>)',
        },
        secondary: {
          DEFAULT: 'hsl(var(--secondary) / <alpha-value>)',
          foreground: 'hsl(var(--secondary-foreground) / <alpha-value>)',
        },
        destructive: {
          DEFAULT: 'hsl(var(--destructive) / <alpha-value>)',
          foreground: 'hsl(var(--destructive-foreground) / <alpha-value>)',
        },
        muted: {
          DEFAULT: 'hsl(var(--muted) / <alpha-value>)',
          foreground: 'hsl(var(--muted-foreground) / <alpha-value>)',
        },
        accent: {
          DEFAULT: 'hsl(var(--accent) / <alpha-value>)',
          foreground: 'hsl(var(--accent-foreground) / <alpha-value>)',
        },
        card: {
          DEFAULT: 'hsl(var(--card) / <alpha-value>)',
          foreground: 'hsl(var(--card-foreground) / <alpha-value>)',
        },
        popover: {
          DEFAULT: 'hsl(var(--popover) / <alpha-value>)',
          foreground: 'hsl(var(--popover-foreground) / <alpha-value>)',
        },
      },
      borderRadius: {
        card: '24px',
        panel: '32px',
      },
      boxShadow: {
        scholesa: '0 18px 45px rgba(15, 45, 75, 0.10)',
        soft: '0 10px 30px rgba(15, 45, 75, 0.08)',
      },
      fontFamily: {
        heading: ['Sora', 'Manrope', 'system-ui', 'sans-serif'],
        body: ['Inter', 'Nunito Sans', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
