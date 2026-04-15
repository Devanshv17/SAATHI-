/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#6541EF',
          dark: '#412896',
        },
        backgroundLight: '#F5FFFF',
        cardBackground: '#C9F5F5',
        lightCyan: '#C9F5F5',
        tealDark: '#00695C',
        correctGreen: '#3F6C40',
        incorrectRed: '#C85257',
        buttonBackgroundLight: '#BFEBF7',
      },
      fontFamily: {
        custom: ['MyCustomFont', 'sans-serif'],
        custom2: ['MyCustom2', 'serif'],
      },
    },
  },
  plugins: [],
}
