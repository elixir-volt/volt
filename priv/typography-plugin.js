var __getOwnPropNames = Object.getOwnPropertyNames;
var __commonJS = (cb, mod) => function __require() {
  return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
};

// node_modules/tailwindcss/dist/colors.js
var require_colors = __commonJS({
  "node_modules/tailwindcss/dist/colors.js"(exports2, module2) {
    "use strict";
    var l = { inherit: "inherit", current: "currentcolor", transparent: "transparent", black: "#000", white: "#fff", slate: { 50: "oklch(98.4% 0.003 247.858)", 100: "oklch(96.8% 0.007 247.896)", 200: "oklch(92.9% 0.013 255.508)", 300: "oklch(86.9% 0.022 252.894)", 400: "oklch(70.4% 0.04 256.788)", 500: "oklch(55.4% 0.046 257.417)", 600: "oklch(44.6% 0.043 257.281)", 700: "oklch(37.2% 0.044 257.287)", 800: "oklch(27.9% 0.041 260.031)", 900: "oklch(20.8% 0.042 265.755)", 950: "oklch(12.9% 0.042 264.695)" }, gray: { 50: "oklch(98.5% 0.002 247.839)", 100: "oklch(96.7% 0.003 264.542)", 200: "oklch(92.8% 0.006 264.531)", 300: "oklch(87.2% 0.01 258.338)", 400: "oklch(70.7% 0.022 261.325)", 500: "oklch(55.1% 0.027 264.364)", 600: "oklch(44.6% 0.03 256.802)", 700: "oklch(37.3% 0.034 259.733)", 800: "oklch(27.8% 0.033 256.848)", 900: "oklch(21% 0.034 264.665)", 950: "oklch(13% 0.028 261.692)" }, zinc: { 50: "oklch(98.5% 0 0)", 100: "oklch(96.7% 0.001 286.375)", 200: "oklch(92% 0.004 286.32)", 300: "oklch(87.1% 0.006 286.286)", 400: "oklch(70.5% 0.015 286.067)", 500: "oklch(55.2% 0.016 285.938)", 600: "oklch(44.2% 0.017 285.786)", 700: "oklch(37% 0.013 285.805)", 800: "oklch(27.4% 0.006 286.033)", 900: "oklch(21% 0.006 285.885)", 950: "oklch(14.1% 0.005 285.823)" }, neutral: { 50: "oklch(98.5% 0 0)", 100: "oklch(97% 0 0)", 200: "oklch(92.2% 0 0)", 300: "oklch(87% 0 0)", 400: "oklch(70.8% 0 0)", 500: "oklch(55.6% 0 0)", 600: "oklch(43.9% 0 0)", 700: "oklch(37.1% 0 0)", 800: "oklch(26.9% 0 0)", 900: "oklch(20.5% 0 0)", 950: "oklch(14.5% 0 0)" }, stone: { 50: "oklch(98.5% 0.001 106.423)", 100: "oklch(97% 0.001 106.424)", 200: "oklch(92.3% 0.003 48.717)", 300: "oklch(86.9% 0.005 56.366)", 400: "oklch(70.9% 0.01 56.259)", 500: "oklch(55.3% 0.013 58.071)", 600: "oklch(44.4% 0.011 73.639)", 700: "oklch(37.4% 0.01 67.558)", 800: "oklch(26.8% 0.007 34.298)", 900: "oklch(21.6% 0.006 56.043)", 950: "oklch(14.7% 0.004 49.25)" }, mauve: { 50: "oklch(98.5% 0 0)", 100: "oklch(96% 0.003 325.6)", 200: "oklch(92.2% 0.005 325.62)", 300: "oklch(86.5% 0.012 325.68)", 400: "oklch(71.1% 0.019 323.02)", 500: "oklch(54.2% 0.034 322.5)", 600: "oklch(43.5% 0.029 321.78)", 700: "oklch(36.4% 0.029 323.89)", 800: "oklch(26.3% 0.024 320.12)", 900: "oklch(21.2% 0.019 322.12)", 950: "oklch(14.5% 0.008 326)" }, olive: { 50: "oklch(98.8% 0.003 106.5)", 100: "oklch(96.6% 0.005 106.5)", 200: "oklch(93% 0.007 106.5)", 300: "oklch(88% 0.011 106.6)", 400: "oklch(73.7% 0.021 106.9)", 500: "oklch(58% 0.031 107.3)", 600: "oklch(46.6% 0.025 107.3)", 700: "oklch(39.4% 0.023 107.4)", 800: "oklch(28.6% 0.016 107.4)", 900: "oklch(22.8% 0.013 107.4)", 950: "oklch(15.3% 0.006 107.1)" }, mist: { 50: "oklch(98.7% 0.002 197.1)", 100: "oklch(96.3% 0.002 197.1)", 200: "oklch(92.5% 0.005 214.3)", 300: "oklch(87.2% 0.007 219.6)", 400: "oklch(72.3% 0.014 214.4)", 500: "oklch(56% 0.021 213.5)", 600: "oklch(45% 0.017 213.2)", 700: "oklch(37.8% 0.015 216)", 800: "oklch(27.5% 0.011 216.9)", 900: "oklch(21.8% 0.008 223.9)", 950: "oklch(14.8% 0.004 228.8)" }, taupe: { 50: "oklch(98.6% 0.002 67.8)", 100: "oklch(96% 0.002 17.2)", 200: "oklch(92.2% 0.005 34.3)", 300: "oklch(86.8% 0.007 39.5)", 400: "oklch(71.4% 0.014 41.2)", 500: "oklch(54.7% 0.021 43.1)", 600: "oklch(43.8% 0.017 39.3)", 700: "oklch(36.7% 0.016 35.7)", 800: "oklch(26.8% 0.011 36.5)", 900: "oklch(21.4% 0.009 43.1)", 950: "oklch(14.7% 0.004 49.3)" }, red: { 50: "oklch(97.1% 0.013 17.38)", 100: "oklch(93.6% 0.032 17.717)", 200: "oklch(88.5% 0.062 18.334)", 300: "oklch(80.8% 0.114 19.571)", 400: "oklch(70.4% 0.191 22.216)", 500: "oklch(63.7% 0.237 25.331)", 600: "oklch(57.7% 0.245 27.325)", 700: "oklch(50.5% 0.213 27.518)", 800: "oklch(44.4% 0.177 26.899)", 900: "oklch(39.6% 0.141 25.723)", 950: "oklch(25.8% 0.092 26.042)" }, orange: { 50: "oklch(98% 0.016 73.684)", 100: "oklch(95.4% 0.038 75.164)", 200: "oklch(90.1% 0.076 70.697)", 300: "oklch(83.7% 0.128 66.29)", 400: "oklch(75% 0.183 55.934)", 500: "oklch(70.5% 0.213 47.604)", 600: "oklch(64.6% 0.222 41.116)", 700: "oklch(55.3% 0.195 38.402)", 800: "oklch(47% 0.157 37.304)", 900: "oklch(40.8% 0.123 38.172)", 950: "oklch(26.6% 0.079 36.259)" }, amber: { 50: "oklch(98.7% 0.022 95.277)", 100: "oklch(96.2% 0.059 95.617)", 200: "oklch(92.4% 0.12 95.746)", 300: "oklch(87.9% 0.169 91.605)", 400: "oklch(82.8% 0.189 84.429)", 500: "oklch(76.9% 0.188 70.08)", 600: "oklch(66.6% 0.179 58.318)", 700: "oklch(55.5% 0.163 48.998)", 800: "oklch(47.3% 0.137 46.201)", 900: "oklch(41.4% 0.112 45.904)", 950: "oklch(27.9% 0.077 45.635)" }, yellow: { 50: "oklch(98.7% 0.026 102.212)", 100: "oklch(97.3% 0.071 103.193)", 200: "oklch(94.5% 0.129 101.54)", 300: "oklch(90.5% 0.182 98.111)", 400: "oklch(85.2% 0.199 91.936)", 500: "oklch(79.5% 0.184 86.047)", 600: "oklch(68.1% 0.162 75.834)", 700: "oklch(55.4% 0.135 66.442)", 800: "oklch(47.6% 0.114 61.907)", 900: "oklch(42.1% 0.095 57.708)", 950: "oklch(28.6% 0.066 53.813)" }, lime: { 50: "oklch(98.6% 0.031 120.757)", 100: "oklch(96.7% 0.067 122.328)", 200: "oklch(93.8% 0.127 124.321)", 300: "oklch(89.7% 0.196 126.665)", 400: "oklch(84.1% 0.238 128.85)", 500: "oklch(76.8% 0.233 130.85)", 600: "oklch(64.8% 0.2 131.684)", 700: "oklch(53.2% 0.157 131.589)", 800: "oklch(45.3% 0.124 130.933)", 900: "oklch(40.5% 0.101 131.063)", 950: "oklch(27.4% 0.072 132.109)" }, green: { 50: "oklch(98.2% 0.018 155.826)", 100: "oklch(96.2% 0.044 156.743)", 200: "oklch(92.5% 0.084 155.995)", 300: "oklch(87.1% 0.15 154.449)", 400: "oklch(79.2% 0.209 151.711)", 500: "oklch(72.3% 0.219 149.579)", 600: "oklch(62.7% 0.194 149.214)", 700: "oklch(52.7% 0.154 150.069)", 800: "oklch(44.8% 0.119 151.328)", 900: "oklch(39.3% 0.095 152.535)", 950: "oklch(26.6% 0.065 152.934)" }, emerald: { 50: "oklch(97.9% 0.021 166.113)", 100: "oklch(95% 0.052 163.051)", 200: "oklch(90.5% 0.093 164.15)", 300: "oklch(84.5% 0.143 164.978)", 400: "oklch(76.5% 0.177 163.223)", 500: "oklch(69.6% 0.17 162.48)", 600: "oklch(59.6% 0.145 163.225)", 700: "oklch(50.8% 0.118 165.612)", 800: "oklch(43.2% 0.095 166.913)", 900: "oklch(37.8% 0.077 168.94)", 950: "oklch(26.2% 0.051 172.552)" }, teal: { 50: "oklch(98.4% 0.014 180.72)", 100: "oklch(95.3% 0.051 180.801)", 200: "oklch(91% 0.096 180.426)", 300: "oklch(85.5% 0.138 181.071)", 400: "oklch(77.7% 0.152 181.912)", 500: "oklch(70.4% 0.14 182.503)", 600: "oklch(60% 0.118 184.704)", 700: "oklch(51.1% 0.096 186.391)", 800: "oklch(43.7% 0.078 188.216)", 900: "oklch(38.6% 0.063 188.416)", 950: "oklch(27.7% 0.046 192.524)" }, cyan: { 50: "oklch(98.4% 0.019 200.873)", 100: "oklch(95.6% 0.045 203.388)", 200: "oklch(91.7% 0.08 205.041)", 300: "oklch(86.5% 0.127 207.078)", 400: "oklch(78.9% 0.154 211.53)", 500: "oklch(71.5% 0.143 215.221)", 600: "oklch(60.9% 0.126 221.723)", 700: "oklch(52% 0.105 223.128)", 800: "oklch(45% 0.085 224.283)", 900: "oklch(39.8% 0.07 227.392)", 950: "oklch(30.2% 0.056 229.695)" }, sky: { 50: "oklch(97.7% 0.013 236.62)", 100: "oklch(95.1% 0.026 236.824)", 200: "oklch(90.1% 0.058 230.902)", 300: "oklch(82.8% 0.111 230.318)", 400: "oklch(74.6% 0.16 232.661)", 500: "oklch(68.5% 0.169 237.323)", 600: "oklch(58.8% 0.158 241.966)", 700: "oklch(50% 0.134 242.749)", 800: "oklch(44.3% 0.11 240.79)", 900: "oklch(39.1% 0.09 240.876)", 950: "oklch(29.3% 0.066 243.157)" }, blue: { 50: "oklch(97% 0.014 254.604)", 100: "oklch(93.2% 0.032 255.585)", 200: "oklch(88.2% 0.059 254.128)", 300: "oklch(80.9% 0.105 251.813)", 400: "oklch(70.7% 0.165 254.624)", 500: "oklch(62.3% 0.214 259.815)", 600: "oklch(54.6% 0.245 262.881)", 700: "oklch(48.8% 0.243 264.376)", 800: "oklch(42.4% 0.199 265.638)", 900: "oklch(37.9% 0.146 265.522)", 950: "oklch(28.2% 0.091 267.935)" }, indigo: { 50: "oklch(96.2% 0.018 272.314)", 100: "oklch(93% 0.034 272.788)", 200: "oklch(87% 0.065 274.039)", 300: "oklch(78.5% 0.115 274.713)", 400: "oklch(67.3% 0.182 276.935)", 500: "oklch(58.5% 0.233 277.117)", 600: "oklch(51.1% 0.262 276.966)", 700: "oklch(45.7% 0.24 277.023)", 800: "oklch(39.8% 0.195 277.366)", 900: "oklch(35.9% 0.144 278.697)", 950: "oklch(25.7% 0.09 281.288)" }, violet: { 50: "oklch(96.9% 0.016 293.756)", 100: "oklch(94.3% 0.029 294.588)", 200: "oklch(89.4% 0.057 293.283)", 300: "oklch(81.1% 0.111 293.571)", 400: "oklch(70.2% 0.183 293.541)", 500: "oklch(60.6% 0.25 292.717)", 600: "oklch(54.1% 0.281 293.009)", 700: "oklch(49.1% 0.27 292.581)", 800: "oklch(43.2% 0.232 292.759)", 900: "oklch(38% 0.189 293.745)", 950: "oklch(28.3% 0.141 291.089)" }, purple: { 50: "oklch(97.7% 0.014 308.299)", 100: "oklch(94.6% 0.033 307.174)", 200: "oklch(90.2% 0.063 306.703)", 300: "oklch(82.7% 0.119 306.383)", 400: "oklch(71.4% 0.203 305.504)", 500: "oklch(62.7% 0.265 303.9)", 600: "oklch(55.8% 0.288 302.321)", 700: "oklch(49.6% 0.265 301.924)", 800: "oklch(43.8% 0.218 303.724)", 900: "oklch(38.1% 0.176 304.987)", 950: "oklch(29.1% 0.149 302.717)" }, fuchsia: { 50: "oklch(97.7% 0.017 320.058)", 100: "oklch(95.2% 0.037 318.852)", 200: "oklch(90.3% 0.076 319.62)", 300: "oklch(83.3% 0.145 321.434)", 400: "oklch(74% 0.238 322.16)", 500: "oklch(66.7% 0.295 322.15)", 600: "oklch(59.1% 0.293 322.896)", 700: "oklch(51.8% 0.253 323.949)", 800: "oklch(45.2% 0.211 324.591)", 900: "oklch(40.1% 0.17 325.612)", 950: "oklch(29.3% 0.136 325.661)" }, pink: { 50: "oklch(97.1% 0.014 343.198)", 100: "oklch(94.8% 0.028 342.258)", 200: "oklch(89.9% 0.061 343.231)", 300: "oklch(82.3% 0.12 346.018)", 400: "oklch(71.8% 0.202 349.761)", 500: "oklch(65.6% 0.241 354.308)", 600: "oklch(59.2% 0.249 0.584)", 700: "oklch(52.5% 0.223 3.958)", 800: "oklch(45.9% 0.187 3.815)", 900: "oklch(40.8% 0.153 2.432)", 950: "oklch(28.4% 0.109 3.907)" }, rose: { 50: "oklch(96.9% 0.015 12.422)", 100: "oklch(94.1% 0.03 12.58)", 200: "oklch(89.2% 0.058 10.001)", 300: "oklch(81% 0.117 11.638)", 400: "oklch(71.2% 0.194 13.428)", 500: "oklch(64.5% 0.246 16.439)", 600: "oklch(58.6% 0.253 17.585)", 700: "oklch(51.4% 0.222 16.935)", 800: "oklch(45.5% 0.188 13.697)", 900: "oklch(41% 0.159 10.272)", 950: "oklch(27.1% 0.105 12.094)" } };
    module2.exports = l;
  }
});

// node_modules/@tailwindcss/typography/src/styles.js
var require_styles = __commonJS({
  "node_modules/@tailwindcss/typography/src/styles.js"(exports2, module2) {
    var colors = require_colors();
    var round = (num) => num.toFixed(7).replace(/(\.[0-9]+?)0+$/, "$1").replace(/\.0$/, "");
    var rem = (px) => `${round(px / 16)}rem`;
    var em = (px, base) => `${round(px / base)}em`;
    var opacity = (color, opacity2) => {
      let hex = color.replace("#", "");
      hex = hex.length === 3 ? hex.replace(/./g, "$&$&") : hex;
      let r = parseInt(hex.substring(0, 2), 16);
      let g = parseInt(hex.substring(2, 4), 16);
      let b = parseInt(hex.substring(4, 6), 16);
      if (Number.isNaN(r) || Number.isNaN(g) || Number.isNaN(b)) {
        return `color-mix(in oklab, ${color} ${opacity2}, transparent)`;
      }
      return `rgb(${r} ${g} ${b} / ${opacity2})`;
    };
    var defaultModifiers = {
      sm: {
        css: [
          {
            fontSize: rem(14),
            lineHeight: round(24 / 14),
            p: {
              marginTop: em(16, 14),
              marginBottom: em(16, 14)
            },
            '[class~="lead"]': {
              fontSize: em(18, 14),
              lineHeight: round(28 / 18),
              marginTop: em(16, 18),
              marginBottom: em(16, 18)
            },
            blockquote: {
              marginTop: em(24, 18),
              marginBottom: em(24, 18),
              paddingInlineStart: em(20, 18)
            },
            h1: {
              fontSize: em(30, 14),
              marginTop: "0",
              marginBottom: em(24, 30),
              lineHeight: round(36 / 30)
            },
            h2: {
              fontSize: em(20, 14),
              marginTop: em(32, 20),
              marginBottom: em(16, 20),
              lineHeight: round(28 / 20)
            },
            h3: {
              fontSize: em(18, 14),
              marginTop: em(28, 18),
              marginBottom: em(8, 18),
              lineHeight: round(28 / 18)
            },
            h4: {
              marginTop: em(20, 14),
              marginBottom: em(8, 14),
              lineHeight: round(20 / 14)
            },
            img: {
              marginTop: em(24, 14),
              marginBottom: em(24, 14)
            },
            picture: {
              marginTop: em(24, 14),
              marginBottom: em(24, 14)
            },
            "picture > img": {
              marginTop: "0",
              marginBottom: "0"
            },
            video: {
              marginTop: em(24, 14),
              marginBottom: em(24, 14)
            },
            kbd: {
              fontSize: em(12, 14),
              borderRadius: rem(5),
              paddingTop: em(2, 14),
              paddingInlineEnd: em(5, 14),
              paddingBottom: em(2, 14),
              paddingInlineStart: em(5, 14)
            },
            code: {
              fontSize: em(12, 14)
            },
            "h2 code": {
              fontSize: em(18, 20)
            },
            "h3 code": {
              fontSize: em(16, 18)
            },
            pre: {
              fontSize: em(12, 14),
              lineHeight: round(20 / 12),
              marginTop: em(20, 12),
              marginBottom: em(20, 12),
              borderRadius: rem(4),
              paddingTop: em(8, 12),
              paddingInlineEnd: em(12, 12),
              paddingBottom: em(8, 12),
              paddingInlineStart: em(12, 12)
            },
            ol: {
              marginTop: em(16, 14),
              marginBottom: em(16, 14),
              paddingInlineStart: em(22, 14)
            },
            ul: {
              marginTop: em(16, 14),
              marginBottom: em(16, 14),
              paddingInlineStart: em(22, 14)
            },
            li: {
              marginTop: em(4, 14),
              marginBottom: em(4, 14)
            },
            "ol > li": {
              paddingInlineStart: em(6, 14)
            },
            "ul > li": {
              paddingInlineStart: em(6, 14)
            },
            "> ul > li p": {
              marginTop: em(8, 14),
              marginBottom: em(8, 14)
            },
            "> ul > li > p:first-child": {
              marginTop: em(16, 14)
            },
            "> ul > li > p:last-child": {
              marginBottom: em(16, 14)
            },
            "> ol > li > p:first-child": {
              marginTop: em(16, 14)
            },
            "> ol > li > p:last-child": {
              marginBottom: em(16, 14)
            },
            "ul ul, ul ol, ol ul, ol ol": {
              marginTop: em(8, 14),
              marginBottom: em(8, 14)
            },
            dl: {
              marginTop: em(16, 14),
              marginBottom: em(16, 14)
            },
            dt: {
              marginTop: em(16, 14)
            },
            dd: {
              marginTop: em(4, 14),
              paddingInlineStart: em(22, 14)
            },
            hr: {
              marginTop: em(40, 14),
              marginBottom: em(40, 14)
            },
            "hr + *": {
              marginTop: "0"
            },
            "h2 + *": {
              marginTop: "0"
            },
            "h3 + *": {
              marginTop: "0"
            },
            "h4 + *": {
              marginTop: "0"
            },
            table: {
              fontSize: em(12, 14),
              lineHeight: round(18 / 12)
            },
            "thead th": {
              paddingInlineEnd: em(12, 12),
              paddingBottom: em(8, 12),
              paddingInlineStart: em(12, 12)
            },
            "thead th:first-child": {
              paddingInlineStart: "0"
            },
            "thead th:last-child": {
              paddingInlineEnd: "0"
            },
            "tbody td, tfoot td": {
              paddingTop: em(8, 12),
              paddingInlineEnd: em(12, 12),
              paddingBottom: em(8, 12),
              paddingInlineStart: em(12, 12)
            },
            "tbody td:first-child, tfoot td:first-child": {
              paddingInlineStart: "0"
            },
            "tbody td:last-child, tfoot td:last-child": {
              paddingInlineEnd: "0"
            },
            figure: {
              marginTop: em(24, 14),
              marginBottom: em(24, 14)
            },
            "figure > *": {
              marginTop: "0",
              marginBottom: "0"
            },
            figcaption: {
              fontSize: em(12, 14),
              lineHeight: round(16 / 12),
              marginTop: em(8, 12)
            }
          },
          {
            "> :first-child": {
              marginTop: "0"
            },
            "> :last-child": {
              marginBottom: "0"
            }
          }
        ]
      },
      base: {
        css: [
          {
            fontSize: rem(16),
            lineHeight: round(28 / 16),
            p: {
              marginTop: em(20, 16),
              marginBottom: em(20, 16)
            },
            '[class~="lead"]': {
              fontSize: em(20, 16),
              lineHeight: round(32 / 20),
              marginTop: em(24, 20),
              marginBottom: em(24, 20)
            },
            blockquote: {
              marginTop: em(32, 20),
              marginBottom: em(32, 20),
              paddingInlineStart: em(20, 20)
            },
            h1: {
              fontSize: em(36, 16),
              marginTop: "0",
              marginBottom: em(32, 36),
              lineHeight: round(40 / 36)
            },
            h2: {
              fontSize: em(24, 16),
              marginTop: em(48, 24),
              marginBottom: em(24, 24),
              lineHeight: round(32 / 24)
            },
            h3: {
              fontSize: em(20, 16),
              marginTop: em(32, 20),
              marginBottom: em(12, 20),
              lineHeight: round(32 / 20)
            },
            h4: {
              marginTop: em(24, 16),
              marginBottom: em(8, 16),
              lineHeight: round(24 / 16)
            },
            img: {
              marginTop: em(32, 16),
              marginBottom: em(32, 16)
            },
            picture: {
              marginTop: em(32, 16),
              marginBottom: em(32, 16)
            },
            "picture > img": {
              marginTop: "0",
              marginBottom: "0"
            },
            video: {
              marginTop: em(32, 16),
              marginBottom: em(32, 16)
            },
            kbd: {
              fontSize: em(14, 16),
              borderRadius: rem(5),
              paddingTop: em(3, 16),
              paddingInlineEnd: em(6, 16),
              paddingBottom: em(3, 16),
              paddingInlineStart: em(6, 16)
            },
            code: {
              fontSize: em(14, 16)
            },
            "h2 code": {
              fontSize: em(21, 24)
            },
            "h3 code": {
              fontSize: em(18, 20)
            },
            pre: {
              fontSize: em(14, 16),
              lineHeight: round(24 / 14),
              marginTop: em(24, 14),
              marginBottom: em(24, 14),
              borderRadius: rem(6),
              paddingTop: em(12, 14),
              paddingInlineEnd: em(16, 14),
              paddingBottom: em(12, 14),
              paddingInlineStart: em(16, 14)
            },
            ol: {
              marginTop: em(20, 16),
              marginBottom: em(20, 16),
              paddingInlineStart: em(26, 16)
            },
            ul: {
              marginTop: em(20, 16),
              marginBottom: em(20, 16),
              paddingInlineStart: em(26, 16)
            },
            li: {
              marginTop: em(8, 16),
              marginBottom: em(8, 16)
            },
            "ol > li": {
              paddingInlineStart: em(6, 16)
            },
            "ul > li": {
              paddingInlineStart: em(6, 16)
            },
            "> ul > li p": {
              marginTop: em(12, 16),
              marginBottom: em(12, 16)
            },
            "> ul > li > p:first-child": {
              marginTop: em(20, 16)
            },
            "> ul > li > p:last-child": {
              marginBottom: em(20, 16)
            },
            "> ol > li > p:first-child": {
              marginTop: em(20, 16)
            },
            "> ol > li > p:last-child": {
              marginBottom: em(20, 16)
            },
            "ul ul, ul ol, ol ul, ol ol": {
              marginTop: em(12, 16),
              marginBottom: em(12, 16)
            },
            dl: {
              marginTop: em(20, 16),
              marginBottom: em(20, 16)
            },
            dt: {
              marginTop: em(20, 16)
            },
            dd: {
              marginTop: em(8, 16),
              paddingInlineStart: em(26, 16)
            },
            hr: {
              marginTop: em(48, 16),
              marginBottom: em(48, 16)
            },
            "hr + *": {
              marginTop: "0"
            },
            "h2 + *": {
              marginTop: "0"
            },
            "h3 + *": {
              marginTop: "0"
            },
            "h4 + *": {
              marginTop: "0"
            },
            table: {
              fontSize: em(14, 16),
              lineHeight: round(24 / 14)
            },
            "thead th": {
              paddingInlineEnd: em(8, 14),
              paddingBottom: em(8, 14),
              paddingInlineStart: em(8, 14)
            },
            "thead th:first-child": {
              paddingInlineStart: "0"
            },
            "thead th:last-child": {
              paddingInlineEnd: "0"
            },
            "tbody td, tfoot td": {
              paddingTop: em(8, 14),
              paddingInlineEnd: em(8, 14),
              paddingBottom: em(8, 14),
              paddingInlineStart: em(8, 14)
            },
            "tbody td:first-child, tfoot td:first-child": {
              paddingInlineStart: "0"
            },
            "tbody td:last-child, tfoot td:last-child": {
              paddingInlineEnd: "0"
            },
            figure: {
              marginTop: em(32, 16),
              marginBottom: em(32, 16)
            },
            "figure > *": {
              marginTop: "0",
              marginBottom: "0"
            },
            figcaption: {
              fontSize: em(14, 16),
              lineHeight: round(20 / 14),
              marginTop: em(12, 14)
            }
          },
          {
            "> :first-child": {
              marginTop: "0"
            },
            "> :last-child": {
              marginBottom: "0"
            }
          }
        ]
      },
      lg: {
        css: [
          {
            fontSize: rem(18),
            lineHeight: round(32 / 18),
            p: {
              marginTop: em(24, 18),
              marginBottom: em(24, 18)
            },
            '[class~="lead"]': {
              fontSize: em(22, 18),
              lineHeight: round(32 / 22),
              marginTop: em(24, 22),
              marginBottom: em(24, 22)
            },
            blockquote: {
              marginTop: em(40, 24),
              marginBottom: em(40, 24),
              paddingInlineStart: em(24, 24)
            },
            h1: {
              fontSize: em(48, 18),
              marginTop: "0",
              marginBottom: em(40, 48),
              lineHeight: round(48 / 48)
            },
            h2: {
              fontSize: em(30, 18),
              marginTop: em(56, 30),
              marginBottom: em(32, 30),
              lineHeight: round(40 / 30)
            },
            h3: {
              fontSize: em(24, 18),
              marginTop: em(40, 24),
              marginBottom: em(16, 24),
              lineHeight: round(36 / 24)
            },
            h4: {
              marginTop: em(32, 18),
              marginBottom: em(8, 18),
              lineHeight: round(28 / 18)
            },
            img: {
              marginTop: em(32, 18),
              marginBottom: em(32, 18)
            },
            picture: {
              marginTop: em(32, 18),
              marginBottom: em(32, 18)
            },
            "picture > img": {
              marginTop: "0",
              marginBottom: "0"
            },
            video: {
              marginTop: em(32, 18),
              marginBottom: em(32, 18)
            },
            kbd: {
              fontSize: em(16, 18),
              borderRadius: rem(5),
              paddingTop: em(4, 18),
              paddingInlineEnd: em(8, 18),
              paddingBottom: em(4, 18),
              paddingInlineStart: em(8, 18)
            },
            code: {
              fontSize: em(16, 18)
            },
            "h2 code": {
              fontSize: em(26, 30)
            },
            "h3 code": {
              fontSize: em(21, 24)
            },
            pre: {
              fontSize: em(16, 18),
              lineHeight: round(28 / 16),
              marginTop: em(32, 16),
              marginBottom: em(32, 16),
              borderRadius: rem(6),
              paddingTop: em(16, 16),
              paddingInlineEnd: em(24, 16),
              paddingBottom: em(16, 16),
              paddingInlineStart: em(24, 16)
            },
            ol: {
              marginTop: em(24, 18),
              marginBottom: em(24, 18),
              paddingInlineStart: em(28, 18)
            },
            ul: {
              marginTop: em(24, 18),
              marginBottom: em(24, 18),
              paddingInlineStart: em(28, 18)
            },
            li: {
              marginTop: em(12, 18),
              marginBottom: em(12, 18)
            },
            "ol > li": {
              paddingInlineStart: em(8, 18)
            },
            "ul > li": {
              paddingInlineStart: em(8, 18)
            },
            "> ul > li p": {
              marginTop: em(16, 18),
              marginBottom: em(16, 18)
            },
            "> ul > li > p:first-child": {
              marginTop: em(24, 18)
            },
            "> ul > li > p:last-child": {
              marginBottom: em(24, 18)
            },
            "> ol > li > p:first-child": {
              marginTop: em(24, 18)
            },
            "> ol > li > p:last-child": {
              marginBottom: em(24, 18)
            },
            "ul ul, ul ol, ol ul, ol ol": {
              marginTop: em(16, 18),
              marginBottom: em(16, 18)
            },
            dl: {
              marginTop: em(24, 18),
              marginBottom: em(24, 18)
            },
            dt: {
              marginTop: em(24, 18)
            },
            dd: {
              marginTop: em(12, 18),
              paddingInlineStart: em(28, 18)
            },
            hr: {
              marginTop: em(56, 18),
              marginBottom: em(56, 18)
            },
            "hr + *": {
              marginTop: "0"
            },
            "h2 + *": {
              marginTop: "0"
            },
            "h3 + *": {
              marginTop: "0"
            },
            "h4 + *": {
              marginTop: "0"
            },
            table: {
              fontSize: em(16, 18),
              lineHeight: round(24 / 16)
            },
            "thead th": {
              paddingInlineEnd: em(12, 16),
              paddingBottom: em(12, 16),
              paddingInlineStart: em(12, 16)
            },
            "thead th:first-child": {
              paddingInlineStart: "0"
            },
            "thead th:last-child": {
              paddingInlineEnd: "0"
            },
            "tbody td, tfoot td": {
              paddingTop: em(12, 16),
              paddingInlineEnd: em(12, 16),
              paddingBottom: em(12, 16),
              paddingInlineStart: em(12, 16)
            },
            "tbody td:first-child, tfoot td:first-child": {
              paddingInlineStart: "0"
            },
            "tbody td:last-child, tfoot td:last-child": {
              paddingInlineEnd: "0"
            },
            figure: {
              marginTop: em(32, 18),
              marginBottom: em(32, 18)
            },
            "figure > *": {
              marginTop: "0",
              marginBottom: "0"
            },
            figcaption: {
              fontSize: em(16, 18),
              lineHeight: round(24 / 16),
              marginTop: em(16, 16)
            }
          },
          {
            "> :first-child": {
              marginTop: "0"
            },
            "> :last-child": {
              marginBottom: "0"
            }
          }
        ]
      },
      xl: {
        css: [
          {
            fontSize: rem(20),
            lineHeight: round(36 / 20),
            p: {
              marginTop: em(24, 20),
              marginBottom: em(24, 20)
            },
            '[class~="lead"]': {
              fontSize: em(24, 20),
              lineHeight: round(36 / 24),
              marginTop: em(24, 24),
              marginBottom: em(24, 24)
            },
            blockquote: {
              marginTop: em(48, 30),
              marginBottom: em(48, 30),
              paddingInlineStart: em(32, 30)
            },
            h1: {
              fontSize: em(56, 20),
              marginTop: "0",
              marginBottom: em(48, 56),
              lineHeight: round(56 / 56)
            },
            h2: {
              fontSize: em(36, 20),
              marginTop: em(56, 36),
              marginBottom: em(32, 36),
              lineHeight: round(40 / 36)
            },
            h3: {
              fontSize: em(30, 20),
              marginTop: em(48, 30),
              marginBottom: em(20, 30),
              lineHeight: round(40 / 30)
            },
            h4: {
              marginTop: em(36, 20),
              marginBottom: em(12, 20),
              lineHeight: round(32 / 20)
            },
            img: {
              marginTop: em(40, 20),
              marginBottom: em(40, 20)
            },
            picture: {
              marginTop: em(40, 20),
              marginBottom: em(40, 20)
            },
            "picture > img": {
              marginTop: "0",
              marginBottom: "0"
            },
            video: {
              marginTop: em(40, 20),
              marginBottom: em(40, 20)
            },
            kbd: {
              fontSize: em(18, 20),
              borderRadius: rem(5),
              paddingTop: em(5, 20),
              paddingInlineEnd: em(8, 20),
              paddingBottom: em(5, 20),
              paddingInlineStart: em(8, 20)
            },
            code: {
              fontSize: em(18, 20)
            },
            "h2 code": {
              fontSize: em(31, 36)
            },
            "h3 code": {
              fontSize: em(27, 30)
            },
            pre: {
              fontSize: em(18, 20),
              lineHeight: round(32 / 18),
              marginTop: em(36, 18),
              marginBottom: em(36, 18),
              borderRadius: rem(8),
              paddingTop: em(20, 18),
              paddingInlineEnd: em(24, 18),
              paddingBottom: em(20, 18),
              paddingInlineStart: em(24, 18)
            },
            ol: {
              marginTop: em(24, 20),
              marginBottom: em(24, 20),
              paddingInlineStart: em(32, 20)
            },
            ul: {
              marginTop: em(24, 20),
              marginBottom: em(24, 20),
              paddingInlineStart: em(32, 20)
            },
            li: {
              marginTop: em(12, 20),
              marginBottom: em(12, 20)
            },
            "ol > li": {
              paddingInlineStart: em(8, 20)
            },
            "ul > li": {
              paddingInlineStart: em(8, 20)
            },
            "> ul > li p": {
              marginTop: em(16, 20),
              marginBottom: em(16, 20)
            },
            "> ul > li > p:first-child": {
              marginTop: em(24, 20)
            },
            "> ul > li > p:last-child": {
              marginBottom: em(24, 20)
            },
            "> ol > li > p:first-child": {
              marginTop: em(24, 20)
            },
            "> ol > li > p:last-child": {
              marginBottom: em(24, 20)
            },
            "ul ul, ul ol, ol ul, ol ol": {
              marginTop: em(16, 20),
              marginBottom: em(16, 20)
            },
            dl: {
              marginTop: em(24, 20),
              marginBottom: em(24, 20)
            },
            dt: {
              marginTop: em(24, 20)
            },
            dd: {
              marginTop: em(12, 20),
              paddingInlineStart: em(32, 20)
            },
            hr: {
              marginTop: em(56, 20),
              marginBottom: em(56, 20)
            },
            "hr + *": {
              marginTop: "0"
            },
            "h2 + *": {
              marginTop: "0"
            },
            "h3 + *": {
              marginTop: "0"
            },
            "h4 + *": {
              marginTop: "0"
            },
            table: {
              fontSize: em(18, 20),
              lineHeight: round(28 / 18)
            },
            "thead th": {
              paddingInlineEnd: em(12, 18),
              paddingBottom: em(16, 18),
              paddingInlineStart: em(12, 18)
            },
            "thead th:first-child": {
              paddingInlineStart: "0"
            },
            "thead th:last-child": {
              paddingInlineEnd: "0"
            },
            "tbody td, tfoot td": {
              paddingTop: em(16, 18),
              paddingInlineEnd: em(12, 18),
              paddingBottom: em(16, 18),
              paddingInlineStart: em(12, 18)
            },
            "tbody td:first-child, tfoot td:first-child": {
              paddingInlineStart: "0"
            },
            "tbody td:last-child, tfoot td:last-child": {
              paddingInlineEnd: "0"
            },
            figure: {
              marginTop: em(40, 20),
              marginBottom: em(40, 20)
            },
            "figure > *": {
              marginTop: "0",
              marginBottom: "0"
            },
            figcaption: {
              fontSize: em(18, 20),
              lineHeight: round(28 / 18),
              marginTop: em(18, 18)
            }
          },
          {
            "> :first-child": {
              marginTop: "0"
            },
            "> :last-child": {
              marginBottom: "0"
            }
          }
        ]
      },
      "2xl": {
        css: [
          {
            fontSize: rem(24),
            lineHeight: round(40 / 24),
            p: {
              marginTop: em(32, 24),
              marginBottom: em(32, 24)
            },
            '[class~="lead"]': {
              fontSize: em(30, 24),
              lineHeight: round(44 / 30),
              marginTop: em(32, 30),
              marginBottom: em(32, 30)
            },
            blockquote: {
              marginTop: em(64, 36),
              marginBottom: em(64, 36),
              paddingInlineStart: em(40, 36)
            },
            h1: {
              fontSize: em(64, 24),
              marginTop: "0",
              marginBottom: em(56, 64),
              lineHeight: round(64 / 64)
            },
            h2: {
              fontSize: em(48, 24),
              marginTop: em(72, 48),
              marginBottom: em(40, 48),
              lineHeight: round(52 / 48)
            },
            h3: {
              fontSize: em(36, 24),
              marginTop: em(56, 36),
              marginBottom: em(24, 36),
              lineHeight: round(44 / 36)
            },
            h4: {
              marginTop: em(40, 24),
              marginBottom: em(16, 24),
              lineHeight: round(36 / 24)
            },
            img: {
              marginTop: em(48, 24),
              marginBottom: em(48, 24)
            },
            picture: {
              marginTop: em(48, 24),
              marginBottom: em(48, 24)
            },
            "picture > img": {
              marginTop: "0",
              marginBottom: "0"
            },
            video: {
              marginTop: em(48, 24),
              marginBottom: em(48, 24)
            },
            kbd: {
              fontSize: em(20, 24),
              borderRadius: rem(6),
              paddingTop: em(6, 24),
              paddingInlineEnd: em(8, 24),
              paddingBottom: em(6, 24),
              paddingInlineStart: em(8, 24)
            },
            code: {
              fontSize: em(20, 24)
            },
            "h2 code": {
              fontSize: em(42, 48)
            },
            "h3 code": {
              fontSize: em(32, 36)
            },
            pre: {
              fontSize: em(20, 24),
              lineHeight: round(36 / 20),
              marginTop: em(40, 20),
              marginBottom: em(40, 20),
              borderRadius: rem(8),
              paddingTop: em(24, 20),
              paddingInlineEnd: em(32, 20),
              paddingBottom: em(24, 20),
              paddingInlineStart: em(32, 20)
            },
            ol: {
              marginTop: em(32, 24),
              marginBottom: em(32, 24),
              paddingInlineStart: em(38, 24)
            },
            ul: {
              marginTop: em(32, 24),
              marginBottom: em(32, 24),
              paddingInlineStart: em(38, 24)
            },
            li: {
              marginTop: em(12, 24),
              marginBottom: em(12, 24)
            },
            "ol > li": {
              paddingInlineStart: em(10, 24)
            },
            "ul > li": {
              paddingInlineStart: em(10, 24)
            },
            "> ul > li p": {
              marginTop: em(20, 24),
              marginBottom: em(20, 24)
            },
            "> ul > li > p:first-child": {
              marginTop: em(32, 24)
            },
            "> ul > li > p:last-child": {
              marginBottom: em(32, 24)
            },
            "> ol > li > p:first-child": {
              marginTop: em(32, 24)
            },
            "> ol > li > p:last-child": {
              marginBottom: em(32, 24)
            },
            "ul ul, ul ol, ol ul, ol ol": {
              marginTop: em(16, 24),
              marginBottom: em(16, 24)
            },
            dl: {
              marginTop: em(32, 24),
              marginBottom: em(32, 24)
            },
            dt: {
              marginTop: em(32, 24)
            },
            dd: {
              marginTop: em(12, 24),
              paddingInlineStart: em(38, 24)
            },
            hr: {
              marginTop: em(72, 24),
              marginBottom: em(72, 24)
            },
            "hr + *": {
              marginTop: "0"
            },
            "h2 + *": {
              marginTop: "0"
            },
            "h3 + *": {
              marginTop: "0"
            },
            "h4 + *": {
              marginTop: "0"
            },
            table: {
              fontSize: em(20, 24),
              lineHeight: round(28 / 20)
            },
            "thead th": {
              paddingInlineEnd: em(12, 20),
              paddingBottom: em(16, 20),
              paddingInlineStart: em(12, 20)
            },
            "thead th:first-child": {
              paddingInlineStart: "0"
            },
            "thead th:last-child": {
              paddingInlineEnd: "0"
            },
            "tbody td, tfoot td": {
              paddingTop: em(16, 20),
              paddingInlineEnd: em(12, 20),
              paddingBottom: em(16, 20),
              paddingInlineStart: em(12, 20)
            },
            "tbody td:first-child, tfoot td:first-child": {
              paddingInlineStart: "0"
            },
            "tbody td:last-child, tfoot td:last-child": {
              paddingInlineEnd: "0"
            },
            figure: {
              marginTop: em(48, 24),
              marginBottom: em(48, 24)
            },
            "figure > *": {
              marginTop: "0",
              marginBottom: "0"
            },
            figcaption: {
              fontSize: em(20, 24),
              lineHeight: round(32 / 20),
              marginTop: em(20, 20)
            }
          },
          {
            "> :first-child": {
              marginTop: "0"
            },
            "> :last-child": {
              marginBottom: "0"
            }
          }
        ]
      },
      // Gray color themes
      slate: {
        css: {
          "--tw-prose-body": colors.slate[700],
          "--tw-prose-headings": colors.slate[900],
          "--tw-prose-lead": colors.slate[600],
          "--tw-prose-links": colors.slate[900],
          "--tw-prose-bold": colors.slate[900],
          "--tw-prose-counters": colors.slate[500],
          "--tw-prose-bullets": colors.slate[300],
          "--tw-prose-hr": colors.slate[200],
          "--tw-prose-quotes": colors.slate[900],
          "--tw-prose-quote-borders": colors.slate[200],
          "--tw-prose-captions": colors.slate[500],
          "--tw-prose-kbd": colors.slate[900],
          "--tw-prose-kbd-shadows": opacity(colors.slate[900], "10%"),
          "--tw-prose-code": colors.slate[900],
          "--tw-prose-pre-code": colors.slate[200],
          "--tw-prose-pre-bg": colors.slate[800],
          "--tw-prose-th-borders": colors.slate[300],
          "--tw-prose-td-borders": colors.slate[200],
          "--tw-prose-invert-body": colors.slate[300],
          "--tw-prose-invert-headings": colors.white,
          "--tw-prose-invert-lead": colors.slate[400],
          "--tw-prose-invert-links": colors.white,
          "--tw-prose-invert-bold": colors.white,
          "--tw-prose-invert-counters": colors.slate[400],
          "--tw-prose-invert-bullets": colors.slate[600],
          "--tw-prose-invert-hr": colors.slate[700],
          "--tw-prose-invert-quotes": colors.slate[100],
          "--tw-prose-invert-quote-borders": colors.slate[700],
          "--tw-prose-invert-captions": colors.slate[400],
          "--tw-prose-invert-kbd": colors.white,
          "--tw-prose-invert-kbd-shadows": opacity(colors.white, "10%"),
          "--tw-prose-invert-code": colors.white,
          "--tw-prose-invert-pre-code": colors.slate[300],
          "--tw-prose-invert-pre-bg": "rgb(0 0 0 / 50%)",
          "--tw-prose-invert-th-borders": colors.slate[600],
          "--tw-prose-invert-td-borders": colors.slate[700]
        }
      },
      gray: {
        css: {
          "--tw-prose-body": colors.gray[700],
          "--tw-prose-headings": colors.gray[900],
          "--tw-prose-lead": colors.gray[600],
          "--tw-prose-links": colors.gray[900],
          "--tw-prose-bold": colors.gray[900],
          "--tw-prose-counters": colors.gray[500],
          "--tw-prose-bullets": colors.gray[300],
          "--tw-prose-hr": colors.gray[200],
          "--tw-prose-quotes": colors.gray[900],
          "--tw-prose-quote-borders": colors.gray[200],
          "--tw-prose-captions": colors.gray[500],
          "--tw-prose-kbd": colors.gray[900],
          "--tw-prose-kbd-shadows": opacity(colors.gray[900], "10%"),
          "--tw-prose-code": colors.gray[900],
          "--tw-prose-pre-code": colors.gray[200],
          "--tw-prose-pre-bg": colors.gray[800],
          "--tw-prose-th-borders": colors.gray[300],
          "--tw-prose-td-borders": colors.gray[200],
          "--tw-prose-invert-body": colors.gray[300],
          "--tw-prose-invert-headings": colors.white,
          "--tw-prose-invert-lead": colors.gray[400],
          "--tw-prose-invert-links": colors.white,
          "--tw-prose-invert-bold": colors.white,
          "--tw-prose-invert-counters": colors.gray[400],
          "--tw-prose-invert-bullets": colors.gray[600],
          "--tw-prose-invert-hr": colors.gray[700],
          "--tw-prose-invert-quotes": colors.gray[100],
          "--tw-prose-invert-quote-borders": colors.gray[700],
          "--tw-prose-invert-captions": colors.gray[400],
          "--tw-prose-invert-kbd": colors.white,
          "--tw-prose-invert-kbd-shadows": opacity(colors.white, "10%"),
          "--tw-prose-invert-code": colors.white,
          "--tw-prose-invert-pre-code": colors.gray[300],
          "--tw-prose-invert-pre-bg": "rgb(0 0 0 / 50%)",
          "--tw-prose-invert-th-borders": colors.gray[600],
          "--tw-prose-invert-td-borders": colors.gray[700]
        }
      },
      zinc: {
        css: {
          "--tw-prose-body": colors.zinc[700],
          "--tw-prose-headings": colors.zinc[900],
          "--tw-prose-lead": colors.zinc[600],
          "--tw-prose-links": colors.zinc[900],
          "--tw-prose-bold": colors.zinc[900],
          "--tw-prose-counters": colors.zinc[500],
          "--tw-prose-bullets": colors.zinc[300],
          "--tw-prose-hr": colors.zinc[200],
          "--tw-prose-quotes": colors.zinc[900],
          "--tw-prose-quote-borders": colors.zinc[200],
          "--tw-prose-captions": colors.zinc[500],
          "--tw-prose-kbd": colors.zinc[900],
          "--tw-prose-kbd-shadows": opacity(colors.zinc[900], "10%"),
          "--tw-prose-code": colors.zinc[900],
          "--tw-prose-pre-code": colors.zinc[200],
          "--tw-prose-pre-bg": colors.zinc[800],
          "--tw-prose-th-borders": colors.zinc[300],
          "--tw-prose-td-borders": colors.zinc[200],
          "--tw-prose-invert-body": colors.zinc[300],
          "--tw-prose-invert-headings": colors.white,
          "--tw-prose-invert-lead": colors.zinc[400],
          "--tw-prose-invert-links": colors.white,
          "--tw-prose-invert-bold": colors.white,
          "--tw-prose-invert-counters": colors.zinc[400],
          "--tw-prose-invert-bullets": colors.zinc[600],
          "--tw-prose-invert-hr": colors.zinc[700],
          "--tw-prose-invert-quotes": colors.zinc[100],
          "--tw-prose-invert-quote-borders": colors.zinc[700],
          "--tw-prose-invert-captions": colors.zinc[400],
          "--tw-prose-invert-kbd": colors.white,
          "--tw-prose-invert-kbd-shadows": opacity(colors.white, "10%"),
          "--tw-prose-invert-code": colors.white,
          "--tw-prose-invert-pre-code": colors.zinc[300],
          "--tw-prose-invert-pre-bg": "rgb(0 0 0 / 50%)",
          "--tw-prose-invert-th-borders": colors.zinc[600],
          "--tw-prose-invert-td-borders": colors.zinc[700]
        }
      },
      neutral: {
        css: {
          "--tw-prose-body": colors.neutral[700],
          "--tw-prose-headings": colors.neutral[900],
          "--tw-prose-lead": colors.neutral[600],
          "--tw-prose-links": colors.neutral[900],
          "--tw-prose-bold": colors.neutral[900],
          "--tw-prose-counters": colors.neutral[500],
          "--tw-prose-bullets": colors.neutral[300],
          "--tw-prose-hr": colors.neutral[200],
          "--tw-prose-quotes": colors.neutral[900],
          "--tw-prose-quote-borders": colors.neutral[200],
          "--tw-prose-captions": colors.neutral[500],
          "--tw-prose-kbd": colors.neutral[900],
          "--tw-prose-kbd-shadows": opacity(colors.neutral[900], "10%"),
          "--tw-prose-code": colors.neutral[900],
          "--tw-prose-pre-code": colors.neutral[200],
          "--tw-prose-pre-bg": colors.neutral[800],
          "--tw-prose-th-borders": colors.neutral[300],
          "--tw-prose-td-borders": colors.neutral[200],
          "--tw-prose-invert-body": colors.neutral[300],
          "--tw-prose-invert-headings": colors.white,
          "--tw-prose-invert-lead": colors.neutral[400],
          "--tw-prose-invert-links": colors.white,
          "--tw-prose-invert-bold": colors.white,
          "--tw-prose-invert-counters": colors.neutral[400],
          "--tw-prose-invert-bullets": colors.neutral[600],
          "--tw-prose-invert-hr": colors.neutral[700],
          "--tw-prose-invert-quotes": colors.neutral[100],
          "--tw-prose-invert-quote-borders": colors.neutral[700],
          "--tw-prose-invert-captions": colors.neutral[400],
          "--tw-prose-invert-kbd": colors.white,
          "--tw-prose-invert-kbd-shadows": opacity(colors.white, "10%"),
          "--tw-prose-invert-code": colors.white,
          "--tw-prose-invert-pre-code": colors.neutral[300],
          "--tw-prose-invert-pre-bg": "rgb(0 0 0 / 50%)",
          "--tw-prose-invert-th-borders": colors.neutral[600],
          "--tw-prose-invert-td-borders": colors.neutral[700]
        }
      },
      stone: {
        css: {
          "--tw-prose-body": colors.stone[700],
          "--tw-prose-headings": colors.stone[900],
          "--tw-prose-lead": colors.stone[600],
          "--tw-prose-links": colors.stone[900],
          "--tw-prose-bold": colors.stone[900],
          "--tw-prose-counters": colors.stone[500],
          "--tw-prose-bullets": colors.stone[300],
          "--tw-prose-hr": colors.stone[200],
          "--tw-prose-quotes": colors.stone[900],
          "--tw-prose-quote-borders": colors.stone[200],
          "--tw-prose-captions": colors.stone[500],
          "--tw-prose-kbd": colors.stone[900],
          "--tw-prose-kbd-shadows": opacity(colors.stone[900], "10%"),
          "--tw-prose-code": colors.stone[900],
          "--tw-prose-pre-code": colors.stone[200],
          "--tw-prose-pre-bg": colors.stone[800],
          "--tw-prose-th-borders": colors.stone[300],
          "--tw-prose-td-borders": colors.stone[200],
          "--tw-prose-invert-body": colors.stone[300],
          "--tw-prose-invert-headings": colors.white,
          "--tw-prose-invert-lead": colors.stone[400],
          "--tw-prose-invert-links": colors.white,
          "--tw-prose-invert-bold": colors.white,
          "--tw-prose-invert-counters": colors.stone[400],
          "--tw-prose-invert-bullets": colors.stone[600],
          "--tw-prose-invert-hr": colors.stone[700],
          "--tw-prose-invert-quotes": colors.stone[100],
          "--tw-prose-invert-quote-borders": colors.stone[700],
          "--tw-prose-invert-captions": colors.stone[400],
          "--tw-prose-invert-kbd": colors.white,
          "--tw-prose-invert-kbd-shadows": opacity(colors.white, "10%"),
          "--tw-prose-invert-code": colors.white,
          "--tw-prose-invert-pre-code": colors.stone[300],
          "--tw-prose-invert-pre-bg": "rgb(0 0 0 / 50%)",
          "--tw-prose-invert-th-borders": colors.stone[600],
          "--tw-prose-invert-td-borders": colors.stone[700]
        }
      },
      // Link-only themes (for backward compatibility)
      red: {
        css: {
          "--tw-prose-links": colors.red[600],
          "--tw-prose-invert-links": colors.red[500]
        }
      },
      orange: {
        css: {
          "--tw-prose-links": colors.orange[600],
          "--tw-prose-invert-links": colors.orange[500]
        }
      },
      amber: {
        css: {
          "--tw-prose-links": colors.amber[600],
          "--tw-prose-invert-links": colors.amber[500]
        }
      },
      yellow: {
        css: {
          "--tw-prose-links": colors.yellow[600],
          "--tw-prose-invert-links": colors.yellow[500]
        }
      },
      lime: {
        css: {
          "--tw-prose-links": colors.lime[600],
          "--tw-prose-invert-links": colors.lime[500]
        }
      },
      green: {
        css: {
          "--tw-prose-links": colors.green[600],
          "--tw-prose-invert-links": colors.green[500]
        }
      },
      emerald: {
        css: {
          "--tw-prose-links": colors.emerald[600],
          "--tw-prose-invert-links": colors.emerald[500]
        }
      },
      teal: {
        css: {
          "--tw-prose-links": colors.teal[600],
          "--tw-prose-invert-links": colors.teal[500]
        }
      },
      cyan: {
        css: {
          "--tw-prose-links": colors.cyan[600],
          "--tw-prose-invert-links": colors.cyan[500]
        }
      },
      sky: {
        css: {
          "--tw-prose-links": colors.sky[600],
          "--tw-prose-invert-links": colors.sky[500]
        }
      },
      blue: {
        css: {
          "--tw-prose-links": colors.blue[600],
          "--tw-prose-invert-links": colors.blue[500]
        }
      },
      indigo: {
        css: {
          "--tw-prose-links": colors.indigo[600],
          "--tw-prose-invert-links": colors.indigo[500]
        }
      },
      violet: {
        css: {
          "--tw-prose-links": colors.violet[600],
          "--tw-prose-invert-links": colors.violet[500]
        }
      },
      purple: {
        css: {
          "--tw-prose-links": colors.purple[600],
          "--tw-prose-invert-links": colors.purple[500]
        }
      },
      fuchsia: {
        css: {
          "--tw-prose-links": colors.fuchsia[600],
          "--tw-prose-invert-links": colors.fuchsia[500]
        }
      },
      pink: {
        css: {
          "--tw-prose-links": colors.pink[600],
          "--tw-prose-invert-links": colors.pink[500]
        }
      },
      rose: {
        css: {
          "--tw-prose-links": colors.rose[600],
          "--tw-prose-invert-links": colors.rose[500]
        }
      },
      // Invert (for dark mode)
      invert: {
        css: {
          "--tw-prose-body": "var(--tw-prose-invert-body)",
          "--tw-prose-headings": "var(--tw-prose-invert-headings)",
          "--tw-prose-lead": "var(--tw-prose-invert-lead)",
          "--tw-prose-links": "var(--tw-prose-invert-links)",
          "--tw-prose-bold": "var(--tw-prose-invert-bold)",
          "--tw-prose-counters": "var(--tw-prose-invert-counters)",
          "--tw-prose-bullets": "var(--tw-prose-invert-bullets)",
          "--tw-prose-hr": "var(--tw-prose-invert-hr)",
          "--tw-prose-quotes": "var(--tw-prose-invert-quotes)",
          "--tw-prose-quote-borders": "var(--tw-prose-invert-quote-borders)",
          "--tw-prose-captions": "var(--tw-prose-invert-captions)",
          "--tw-prose-kbd": "var(--tw-prose-invert-kbd)",
          "--tw-prose-kbd-shadows": "var(--tw-prose-invert-kbd-shadows)",
          "--tw-prose-code": "var(--tw-prose-invert-code)",
          "--tw-prose-pre-code": "var(--tw-prose-invert-pre-code)",
          "--tw-prose-pre-bg": "var(--tw-prose-invert-pre-bg)",
          "--tw-prose-th-borders": "var(--tw-prose-invert-th-borders)",
          "--tw-prose-td-borders": "var(--tw-prose-invert-td-borders)"
        }
      }
    };
    module2.exports = {
      DEFAULT: {
        css: [
          {
            color: "var(--tw-prose-body)",
            maxWidth: "65ch",
            p: {},
            // Required to maintain correct order when merging
            '[class~="lead"]': {
              color: "var(--tw-prose-lead)"
            },
            a: {
              color: "var(--tw-prose-links)",
              textDecoration: "underline",
              fontWeight: "500"
            },
            strong: {
              color: "var(--tw-prose-bold)",
              fontWeight: "600"
            },
            "a strong": {
              color: "inherit"
            },
            "blockquote strong": {
              color: "inherit"
            },
            "thead th strong": {
              color: "inherit"
            },
            ol: {
              listStyleType: "decimal"
            },
            'ol[type="A"]': {
              listStyleType: "upper-alpha"
            },
            'ol[type="a"]': {
              listStyleType: "lower-alpha"
            },
            'ol[type="A" s]': {
              listStyleType: "upper-alpha"
            },
            'ol[type="a" s]': {
              listStyleType: "lower-alpha"
            },
            'ol[type="I"]': {
              listStyleType: "upper-roman"
            },
            'ol[type="i"]': {
              listStyleType: "lower-roman"
            },
            'ol[type="I" s]': {
              listStyleType: "upper-roman"
            },
            'ol[type="i" s]': {
              listStyleType: "lower-roman"
            },
            'ol[type="1"]': {
              listStyleType: "decimal"
            },
            ul: {
              listStyleType: "disc"
            },
            "ol > li::marker": {
              fontWeight: "400",
              color: "var(--tw-prose-counters)"
            },
            "ul > li::marker": {
              color: "var(--tw-prose-bullets)"
            },
            dt: {
              color: "var(--tw-prose-headings)",
              fontWeight: "600"
            },
            hr: {
              borderColor: "var(--tw-prose-hr)",
              borderTopWidth: "1px"
            },
            blockquote: {
              fontWeight: "500",
              fontStyle: "italic",
              color: "var(--tw-prose-quotes)",
              borderInlineStartWidth: "0.25rem",
              borderInlineStartColor: "var(--tw-prose-quote-borders)",
              quotes: '"\\201C""\\201D""\\2018""\\2019"'
            },
            "blockquote p:first-of-type::before": {
              content: "open-quote"
            },
            "blockquote p:last-of-type::after": {
              content: "close-quote"
            },
            h1: {
              color: "var(--tw-prose-headings)",
              fontWeight: "800"
            },
            "h1 strong": {
              fontWeight: "900",
              color: "inherit"
            },
            h2: {
              color: "var(--tw-prose-headings)",
              fontWeight: "700"
            },
            "h2 strong": {
              fontWeight: "800",
              color: "inherit"
            },
            h3: {
              color: "var(--tw-prose-headings)",
              fontWeight: "600"
            },
            "h3 strong": {
              fontWeight: "700",
              color: "inherit"
            },
            h4: {
              color: "var(--tw-prose-headings)",
              fontWeight: "600"
            },
            "h4 strong": {
              fontWeight: "700",
              color: "inherit"
            },
            img: {},
            // Required to maintain correct order when merging
            picture: {
              display: "block"
            },
            video: {},
            // Required to maintain correct order when merging
            kbd: {
              fontWeight: "500",
              fontFamily: "inherit",
              color: "var(--tw-prose-kbd)",
              boxShadow: "0 0 0 1px var(--tw-prose-kbd-shadows), 0 3px 0 var(--tw-prose-kbd-shadows)"
            },
            code: {
              color: "var(--tw-prose-code)",
              fontWeight: "600"
            },
            "code::before": {
              content: '"`"'
            },
            "code::after": {
              content: '"`"'
            },
            "a code": {
              color: "inherit"
            },
            "h1 code": {
              color: "inherit"
            },
            "h2 code": {
              color: "inherit"
            },
            "h3 code": {
              color: "inherit"
            },
            "h4 code": {
              color: "inherit"
            },
            "blockquote code": {
              color: "inherit"
            },
            "thead th code": {
              color: "inherit"
            },
            pre: {
              color: "var(--tw-prose-pre-code)",
              backgroundColor: "var(--tw-prose-pre-bg)",
              overflowX: "auto",
              fontWeight: "400"
            },
            "pre code": {
              backgroundColor: "transparent",
              borderWidth: "0",
              borderRadius: "0",
              padding: "0",
              fontWeight: "inherit",
              color: "inherit",
              fontSize: "inherit",
              fontFamily: "inherit",
              lineHeight: "inherit"
            },
            "pre code::before": {
              content: "none"
            },
            "pre code::after": {
              content: "none"
            },
            table: {
              width: "100%",
              tableLayout: "auto",
              marginTop: em(32, 16),
              marginBottom: em(32, 16)
            },
            thead: {
              borderBottomWidth: "1px",
              borderBottomColor: "var(--tw-prose-th-borders)"
            },
            "thead th": {
              color: "var(--tw-prose-headings)",
              fontWeight: "600",
              verticalAlign: "bottom"
            },
            "tbody tr": {
              borderBottomWidth: "1px",
              borderBottomColor: "var(--tw-prose-td-borders)"
            },
            "tbody tr:last-child": {
              borderBottomWidth: "0"
            },
            "tbody td": {
              verticalAlign: "baseline"
            },
            tfoot: {
              borderTopWidth: "1px",
              borderTopColor: "var(--tw-prose-th-borders)"
            },
            "tfoot td": {
              verticalAlign: "top"
            },
            "th, td": {
              textAlign: "start"
            },
            "figure > *": {},
            // Required to maintain correct order when merging
            figcaption: {
              color: "var(--tw-prose-captions)"
            }
          },
          defaultModifiers.gray.css,
          ...defaultModifiers.base.css
        ]
      },
      ...defaultModifiers
    };
  }
});

// node_modules/postcss-selector-parser/dist/util/unesc.js
var require_unesc = __commonJS({
  "node_modules/postcss-selector-parser/dist/util/unesc.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = unesc;
    function gobbleHex(str) {
      var lower = str.toLowerCase();
      var hex = "";
      var spaceTerminated = false;
      for (var i = 0; i < 6 && lower[i] !== void 0; i++) {
        var code = lower.charCodeAt(i);
        var valid = code >= 97 && code <= 102 || code >= 48 && code <= 57;
        spaceTerminated = code === 32;
        if (!valid) {
          break;
        }
        hex += lower[i];
      }
      if (hex.length === 0) {
        return void 0;
      }
      var codePoint = parseInt(hex, 16);
      var isSurrogate = codePoint >= 55296 && codePoint <= 57343;
      if (isSurrogate || codePoint === 0 || codePoint > 1114111) {
        return ["\uFFFD", hex.length + (spaceTerminated ? 1 : 0)];
      }
      return [String.fromCodePoint(codePoint), hex.length + (spaceTerminated ? 1 : 0)];
    }
    var CONTAINS_ESCAPE = /\\/;
    function unesc(str) {
      var needToProcess = CONTAINS_ESCAPE.test(str);
      if (!needToProcess) {
        return str;
      }
      var ret = "";
      for (var i = 0; i < str.length; i++) {
        if (str[i] === "\\") {
          var gobbled = gobbleHex(str.slice(i + 1, i + 7));
          if (gobbled !== void 0) {
            ret += gobbled[0];
            i += gobbled[1];
            continue;
          }
          if (str[i + 1] === "\\") {
            ret += "\\";
            i++;
            continue;
          }
          if (str.length === i + 1) {
            ret += str[i];
          }
          continue;
        }
        ret += str[i];
      }
      return ret;
    }
    module2.exports = exports2.default;
  }
});

// node_modules/postcss-selector-parser/dist/util/getProp.js
var require_getProp = __commonJS({
  "node_modules/postcss-selector-parser/dist/util/getProp.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = getProp;
    function getProp(obj) {
      for (var _len = arguments.length, props = new Array(_len > 1 ? _len - 1 : 0), _key = 1; _key < _len; _key++) {
        props[_key - 1] = arguments[_key];
      }
      while (props.length > 0) {
        var prop = props.shift();
        if (!obj[prop]) {
          return void 0;
        }
        obj = obj[prop];
      }
      return obj;
    }
    module2.exports = exports2.default;
  }
});

// node_modules/postcss-selector-parser/dist/util/ensureObject.js
var require_ensureObject = __commonJS({
  "node_modules/postcss-selector-parser/dist/util/ensureObject.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = ensureObject;
    function ensureObject(obj) {
      for (var _len = arguments.length, props = new Array(_len > 1 ? _len - 1 : 0), _key = 1; _key < _len; _key++) {
        props[_key - 1] = arguments[_key];
      }
      while (props.length > 0) {
        var prop = props.shift();
        if (!obj[prop]) {
          obj[prop] = {};
        }
        obj = obj[prop];
      }
    }
    module2.exports = exports2.default;
  }
});

// node_modules/postcss-selector-parser/dist/util/stripComments.js
var require_stripComments = __commonJS({
  "node_modules/postcss-selector-parser/dist/util/stripComments.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = stripComments;
    function stripComments(str) {
      var s = "";
      var commentStart = str.indexOf("/*");
      var lastEnd = 0;
      while (commentStart >= 0) {
        s = s + str.slice(lastEnd, commentStart);
        var commentEnd = str.indexOf("*/", commentStart + 2);
        if (commentEnd < 0) {
          return s;
        }
        lastEnd = commentEnd + 2;
        commentStart = str.indexOf("/*", lastEnd);
      }
      s = s + str.slice(lastEnd);
      return s;
    }
    module2.exports = exports2.default;
  }
});

// node_modules/postcss-selector-parser/dist/util/index.js
var require_util = __commonJS({
  "node_modules/postcss-selector-parser/dist/util/index.js"(exports2) {
    "use strict";
    exports2.__esModule = true;
    exports2.stripComments = exports2.ensureObject = exports2.getProp = exports2.unesc = void 0;
    var _unesc = _interopRequireDefault(require_unesc());
    exports2.unesc = _unesc["default"];
    var _getProp = _interopRequireDefault(require_getProp());
    exports2.getProp = _getProp["default"];
    var _ensureObject = _interopRequireDefault(require_ensureObject());
    exports2.ensureObject = _ensureObject["default"];
    var _stripComments = _interopRequireDefault(require_stripComments());
    exports2.stripComments = _stripComments["default"];
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
  }
});

// node_modules/postcss-selector-parser/dist/selectors/node.js
var require_node = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/node.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = void 0;
    var _util = require_util();
    function _defineProperties(target, props) {
      for (var i = 0; i < props.length; i++) {
        var descriptor = props[i];
        descriptor.enumerable = descriptor.enumerable || false;
        descriptor.configurable = true;
        if ("value" in descriptor) descriptor.writable = true;
        Object.defineProperty(target, descriptor.key, descriptor);
      }
    }
    function _createClass(Constructor, protoProps, staticProps) {
      if (protoProps) _defineProperties(Constructor.prototype, protoProps);
      if (staticProps) _defineProperties(Constructor, staticProps);
      return Constructor;
    }
    var cloneNode = function cloneNode2(obj, parent) {
      if (typeof obj !== "object" || obj === null) {
        return obj;
      }
      var cloned = new obj.constructor();
      for (var i in obj) {
        if (!obj.hasOwnProperty(i)) {
          continue;
        }
        var value = obj[i];
        var type = typeof value;
        if (i === "parent" && type === "object") {
          if (parent) {
            cloned[i] = parent;
          }
        } else if (value instanceof Array) {
          cloned[i] = value.map(function(j) {
            return cloneNode2(j, cloned);
          });
        } else {
          cloned[i] = cloneNode2(value, cloned);
        }
      }
      return cloned;
    };
    var Node = /* @__PURE__ */ (function() {
      function Node2(opts) {
        if (opts === void 0) {
          opts = {};
        }
        Object.assign(this, opts);
        this.spaces = this.spaces || {};
        this.spaces.before = this.spaces.before || "";
        this.spaces.after = this.spaces.after || "";
      }
      var _proto = Node2.prototype;
      _proto.remove = function remove() {
        if (this.parent) {
          this.parent.removeChild(this);
        }
        this.parent = void 0;
        return this;
      };
      _proto.replaceWith = function replaceWith() {
        if (this.parent) {
          for (var index in arguments) {
            this.parent.insertBefore(this, arguments[index]);
          }
          this.remove();
        }
        return this;
      };
      _proto.next = function next() {
        return this.parent.at(this.parent.index(this) + 1);
      };
      _proto.prev = function prev() {
        return this.parent.at(this.parent.index(this) - 1);
      };
      _proto.clone = function clone(overrides) {
        if (overrides === void 0) {
          overrides = {};
        }
        var cloned = cloneNode(this);
        for (var name in overrides) {
          cloned[name] = overrides[name];
        }
        return cloned;
      };
      _proto.appendToPropertyAndEscape = function appendToPropertyAndEscape(name, value, valueEscaped) {
        if (!this.raws) {
          this.raws = {};
        }
        var originalValue = this[name];
        var originalEscaped = this.raws[name];
        this[name] = originalValue + value;
        if (originalEscaped || valueEscaped !== value) {
          this.raws[name] = (originalEscaped || originalValue) + valueEscaped;
        } else {
          delete this.raws[name];
        }
      };
      _proto.setPropertyAndEscape = function setPropertyAndEscape(name, value, valueEscaped) {
        if (!this.raws) {
          this.raws = {};
        }
        this[name] = value;
        this.raws[name] = valueEscaped;
      };
      _proto.setPropertyWithoutEscape = function setPropertyWithoutEscape(name, value) {
        this[name] = value;
        if (this.raws) {
          delete this.raws[name];
        }
      };
      _proto.isAtPosition = function isAtPosition(line, column) {
        if (this.source && this.source.start && this.source.end) {
          if (this.source.start.line > line) {
            return false;
          }
          if (this.source.end.line < line) {
            return false;
          }
          if (this.source.start.line === line && this.source.start.column > column) {
            return false;
          }
          if (this.source.end.line === line && this.source.end.column < column) {
            return false;
          }
          return true;
        }
        return void 0;
      };
      _proto.stringifyProperty = function stringifyProperty(name) {
        return this.raws && this.raws[name] || this[name];
      };
      _proto.valueToString = function valueToString() {
        return String(this.stringifyProperty("value"));
      };
      _proto.toString = function toString() {
        return [this.rawSpaceBefore, this.valueToString(), this.rawSpaceAfter].join("");
      };
      _createClass(Node2, [{
        key: "rawSpaceBefore",
        get: function get() {
          var rawSpace = this.raws && this.raws.spaces && this.raws.spaces.before;
          if (rawSpace === void 0) {
            rawSpace = this.spaces && this.spaces.before;
          }
          return rawSpace || "";
        },
        set: function set(raw) {
          (0, _util.ensureObject)(this, "raws", "spaces");
          this.raws.spaces.before = raw;
        }
      }, {
        key: "rawSpaceAfter",
        get: function get() {
          var rawSpace = this.raws && this.raws.spaces && this.raws.spaces.after;
          if (rawSpace === void 0) {
            rawSpace = this.spaces.after;
          }
          return rawSpace || "";
        },
        set: function set(raw) {
          (0, _util.ensureObject)(this, "raws", "spaces");
          this.raws.spaces.after = raw;
        }
      }]);
      return Node2;
    })();
    exports2["default"] = Node;
    module2.exports = exports2.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/types.js
var require_types = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/types.js"(exports2) {
    "use strict";
    exports2.__esModule = true;
    exports2.UNIVERSAL = exports2.ATTRIBUTE = exports2.CLASS = exports2.COMBINATOR = exports2.COMMENT = exports2.ID = exports2.NESTING = exports2.PSEUDO = exports2.ROOT = exports2.SELECTOR = exports2.STRING = exports2.TAG = void 0;
    var TAG = "tag";
    exports2.TAG = TAG;
    var STRING = "string";
    exports2.STRING = STRING;
    var SELECTOR = "selector";
    exports2.SELECTOR = SELECTOR;
    var ROOT = "root";
    exports2.ROOT = ROOT;
    var PSEUDO = "pseudo";
    exports2.PSEUDO = PSEUDO;
    var NESTING = "nesting";
    exports2.NESTING = NESTING;
    var ID = "id";
    exports2.ID = ID;
    var COMMENT = "comment";
    exports2.COMMENT = COMMENT;
    var COMBINATOR = "combinator";
    exports2.COMBINATOR = COMBINATOR;
    var CLASS = "class";
    exports2.CLASS = CLASS;
    var ATTRIBUTE = "attribute";
    exports2.ATTRIBUTE = ATTRIBUTE;
    var UNIVERSAL = "universal";
    exports2.UNIVERSAL = UNIVERSAL;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/container.js
var require_container = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/container.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = void 0;
    var _node = _interopRequireDefault(require_node());
    var types = _interopRequireWildcard(require_types());
    function _getRequireWildcardCache() {
      if (typeof WeakMap !== "function") return null;
      var cache = /* @__PURE__ */ new WeakMap();
      _getRequireWildcardCache = function _getRequireWildcardCache2() {
        return cache;
      };
      return cache;
    }
    function _interopRequireWildcard(obj) {
      if (obj && obj.__esModule) {
        return obj;
      }
      if (obj === null || typeof obj !== "object" && typeof obj !== "function") {
        return { "default": obj };
      }
      var cache = _getRequireWildcardCache();
      if (cache && cache.has(obj)) {
        return cache.get(obj);
      }
      var newObj = {};
      var hasPropertyDescriptor = Object.defineProperty && Object.getOwnPropertyDescriptor;
      for (var key in obj) {
        if (Object.prototype.hasOwnProperty.call(obj, key)) {
          var desc = hasPropertyDescriptor ? Object.getOwnPropertyDescriptor(obj, key) : null;
          if (desc && (desc.get || desc.set)) {
            Object.defineProperty(newObj, key, desc);
          } else {
            newObj[key] = obj[key];
          }
        }
      }
      newObj["default"] = obj;
      if (cache) {
        cache.set(obj, newObj);
      }
      return newObj;
    }
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _createForOfIteratorHelperLoose(o, allowArrayLike) {
      var it;
      if (typeof Symbol === "undefined" || o[Symbol.iterator] == null) {
        if (Array.isArray(o) || (it = _unsupportedIterableToArray(o)) || allowArrayLike && o && typeof o.length === "number") {
          if (it) o = it;
          var i = 0;
          return function() {
            if (i >= o.length) return { done: true };
            return { done: false, value: o[i++] };
          };
        }
        throw new TypeError("Invalid attempt to iterate non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method.");
      }
      it = o[Symbol.iterator]();
      return it.next.bind(it);
    }
    function _unsupportedIterableToArray(o, minLen) {
      if (!o) return;
      if (typeof o === "string") return _arrayLikeToArray(o, minLen);
      var n = Object.prototype.toString.call(o).slice(8, -1);
      if (n === "Object" && o.constructor) n = o.constructor.name;
      if (n === "Map" || n === "Set") return Array.from(o);
      if (n === "Arguments" || /^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(n)) return _arrayLikeToArray(o, minLen);
    }
    function _arrayLikeToArray(arr, len) {
      if (len == null || len > arr.length) len = arr.length;
      for (var i = 0, arr2 = new Array(len); i < len; i++) {
        arr2[i] = arr[i];
      }
      return arr2;
    }
    function _defineProperties(target, props) {
      for (var i = 0; i < props.length; i++) {
        var descriptor = props[i];
        descriptor.enumerable = descriptor.enumerable || false;
        descriptor.configurable = true;
        if ("value" in descriptor) descriptor.writable = true;
        Object.defineProperty(target, descriptor.key, descriptor);
      }
    }
    function _createClass(Constructor, protoProps, staticProps) {
      if (protoProps) _defineProperties(Constructor.prototype, protoProps);
      if (staticProps) _defineProperties(Constructor, staticProps);
      return Constructor;
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Container = /* @__PURE__ */ (function(_Node) {
      _inheritsLoose(Container2, _Node);
      function Container2(opts) {
        var _this;
        _this = _Node.call(this, opts) || this;
        if (!_this.nodes) {
          _this.nodes = [];
        }
        return _this;
      }
      var _proto = Container2.prototype;
      _proto.append = function append(selector) {
        selector.parent = this;
        this.nodes.push(selector);
        return this;
      };
      _proto.prepend = function prepend(selector) {
        selector.parent = this;
        this.nodes.unshift(selector);
        return this;
      };
      _proto.at = function at(index) {
        return this.nodes[index];
      };
      _proto.index = function index(child) {
        if (typeof child === "number") {
          return child;
        }
        return this.nodes.indexOf(child);
      };
      _proto.removeChild = function removeChild(child) {
        child = this.index(child);
        this.at(child).parent = void 0;
        this.nodes.splice(child, 1);
        var index;
        for (var id in this.indexes) {
          index = this.indexes[id];
          if (index >= child) {
            this.indexes[id] = index - 1;
          }
        }
        return this;
      };
      _proto.removeAll = function removeAll() {
        for (var _iterator = _createForOfIteratorHelperLoose(this.nodes), _step; !(_step = _iterator()).done; ) {
          var node = _step.value;
          node.parent = void 0;
        }
        this.nodes = [];
        return this;
      };
      _proto.empty = function empty() {
        return this.removeAll();
      };
      _proto.insertAfter = function insertAfter(oldNode, newNode) {
        newNode.parent = this;
        var oldIndex = this.index(oldNode);
        this.nodes.splice(oldIndex + 1, 0, newNode);
        newNode.parent = this;
        var index;
        for (var id in this.indexes) {
          index = this.indexes[id];
          if (oldIndex <= index) {
            this.indexes[id] = index + 1;
          }
        }
        return this;
      };
      _proto.insertBefore = function insertBefore(oldNode, newNode) {
        newNode.parent = this;
        var oldIndex = this.index(oldNode);
        this.nodes.splice(oldIndex, 0, newNode);
        newNode.parent = this;
        var index;
        for (var id in this.indexes) {
          index = this.indexes[id];
          if (index <= oldIndex) {
            this.indexes[id] = index + 1;
          }
        }
        return this;
      };
      _proto._findChildAtPosition = function _findChildAtPosition(line, col) {
        var found = void 0;
        this.each(function(node) {
          if (node.atPosition) {
            var foundChild = node.atPosition(line, col);
            if (foundChild) {
              found = foundChild;
              return false;
            }
          } else if (node.isAtPosition(line, col)) {
            found = node;
            return false;
          }
        });
        return found;
      };
      _proto.atPosition = function atPosition(line, col) {
        if (this.isAtPosition(line, col)) {
          return this._findChildAtPosition(line, col) || this;
        } else {
          return void 0;
        }
      };
      _proto._inferEndPosition = function _inferEndPosition() {
        if (this.last && this.last.source && this.last.source.end) {
          this.source = this.source || {};
          this.source.end = this.source.end || {};
          Object.assign(this.source.end, this.last.source.end);
        }
      };
      _proto.each = function each(callback) {
        if (!this.lastEach) {
          this.lastEach = 0;
        }
        if (!this.indexes) {
          this.indexes = {};
        }
        this.lastEach++;
        var id = this.lastEach;
        this.indexes[id] = 0;
        if (!this.length) {
          return void 0;
        }
        var index, result;
        while (this.indexes[id] < this.length) {
          index = this.indexes[id];
          result = callback(this.at(index), index);
          if (result === false) {
            break;
          }
          this.indexes[id] += 1;
        }
        delete this.indexes[id];
        if (result === false) {
          return false;
        }
      };
      _proto.walk = function walk(callback) {
        return this.each(function(node, i) {
          var result = callback(node, i);
          if (result !== false && node.length) {
            result = node.walk(callback);
          }
          if (result === false) {
            return false;
          }
        });
      };
      _proto.walkAttributes = function walkAttributes(callback) {
        var _this2 = this;
        return this.walk(function(selector) {
          if (selector.type === types.ATTRIBUTE) {
            return callback.call(_this2, selector);
          }
        });
      };
      _proto.walkClasses = function walkClasses(callback) {
        var _this3 = this;
        return this.walk(function(selector) {
          if (selector.type === types.CLASS) {
            return callback.call(_this3, selector);
          }
        });
      };
      _proto.walkCombinators = function walkCombinators(callback) {
        var _this4 = this;
        return this.walk(function(selector) {
          if (selector.type === types.COMBINATOR) {
            return callback.call(_this4, selector);
          }
        });
      };
      _proto.walkComments = function walkComments(callback) {
        var _this5 = this;
        return this.walk(function(selector) {
          if (selector.type === types.COMMENT) {
            return callback.call(_this5, selector);
          }
        });
      };
      _proto.walkIds = function walkIds(callback) {
        var _this6 = this;
        return this.walk(function(selector) {
          if (selector.type === types.ID) {
            return callback.call(_this6, selector);
          }
        });
      };
      _proto.walkNesting = function walkNesting(callback) {
        var _this7 = this;
        return this.walk(function(selector) {
          if (selector.type === types.NESTING) {
            return callback.call(_this7, selector);
          }
        });
      };
      _proto.walkPseudos = function walkPseudos(callback) {
        var _this8 = this;
        return this.walk(function(selector) {
          if (selector.type === types.PSEUDO) {
            return callback.call(_this8, selector);
          }
        });
      };
      _proto.walkTags = function walkTags(callback) {
        var _this9 = this;
        return this.walk(function(selector) {
          if (selector.type === types.TAG) {
            return callback.call(_this9, selector);
          }
        });
      };
      _proto.walkUniversals = function walkUniversals(callback) {
        var _this10 = this;
        return this.walk(function(selector) {
          if (selector.type === types.UNIVERSAL) {
            return callback.call(_this10, selector);
          }
        });
      };
      _proto.split = function split(callback) {
        var _this11 = this;
        var current = [];
        return this.reduce(function(memo, node, index) {
          var split2 = callback.call(_this11, node);
          current.push(node);
          if (split2) {
            memo.push(current);
            current = [];
          } else if (index === _this11.length - 1) {
            memo.push(current);
          }
          return memo;
        }, []);
      };
      _proto.map = function map(callback) {
        return this.nodes.map(callback);
      };
      _proto.reduce = function reduce(callback, memo) {
        return this.nodes.reduce(callback, memo);
      };
      _proto.every = function every(callback) {
        return this.nodes.every(callback);
      };
      _proto.some = function some(callback) {
        return this.nodes.some(callback);
      };
      _proto.filter = function filter(callback) {
        return this.nodes.filter(callback);
      };
      _proto.sort = function sort(callback) {
        return this.nodes.sort(callback);
      };
      _proto.toString = function toString() {
        return this.map(String).join("");
      };
      _createClass(Container2, [{
        key: "first",
        get: function get() {
          return this.at(0);
        }
      }, {
        key: "last",
        get: function get() {
          return this.at(this.length - 1);
        }
      }, {
        key: "length",
        get: function get() {
          return this.nodes.length;
        }
      }]);
      return Container2;
    })(_node["default"]);
    exports2["default"] = Container;
    module2.exports = exports2.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/root.js
var require_root = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/root.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = void 0;
    var _container = _interopRequireDefault(require_container());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _defineProperties(target, props) {
      for (var i = 0; i < props.length; i++) {
        var descriptor = props[i];
        descriptor.enumerable = descriptor.enumerable || false;
        descriptor.configurable = true;
        if ("value" in descriptor) descriptor.writable = true;
        Object.defineProperty(target, descriptor.key, descriptor);
      }
    }
    function _createClass(Constructor, protoProps, staticProps) {
      if (protoProps) _defineProperties(Constructor.prototype, protoProps);
      if (staticProps) _defineProperties(Constructor, staticProps);
      return Constructor;
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Root = /* @__PURE__ */ (function(_Container) {
      _inheritsLoose(Root2, _Container);
      function Root2(opts) {
        var _this;
        _this = _Container.call(this, opts) || this;
        _this.type = _types.ROOT;
        return _this;
      }
      var _proto = Root2.prototype;
      _proto.toString = function toString() {
        var str = this.reduce(function(memo, selector) {
          memo.push(String(selector));
          return memo;
        }, []).join(",");
        return this.trailingComma ? str + "," : str;
      };
      _proto.error = function error(message, options) {
        if (this._error) {
          return this._error(message, options);
        } else {
          return new Error(message);
        }
      };
      _createClass(Root2, [{
        key: "errorGenerator",
        set: function set(handler) {
          this._error = handler;
        }
      }]);
      return Root2;
    })(_container["default"]);
    exports2["default"] = Root;
    module2.exports = exports2.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/selector.js
var require_selector = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/selector.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = void 0;
    var _container = _interopRequireDefault(require_container());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Selector = /* @__PURE__ */ (function(_Container) {
      _inheritsLoose(Selector2, _Container);
      function Selector2(opts) {
        var _this;
        _this = _Container.call(this, opts) || this;
        _this.type = _types.SELECTOR;
        return _this;
      }
      return Selector2;
    })(_container["default"]);
    exports2["default"] = Selector;
    module2.exports = exports2.default;
  }
});

// node_modules/cssesc/cssesc.js
var require_cssesc = __commonJS({
  "node_modules/cssesc/cssesc.js"(exports2, module2) {
    "use strict";
    var object = {};
    var hasOwnProperty = object.hasOwnProperty;
    var merge = function merge2(options, defaults) {
      if (!options) {
        return defaults;
      }
      var result = {};
      for (var key in defaults) {
        result[key] = hasOwnProperty.call(options, key) ? options[key] : defaults[key];
      }
      return result;
    };
    var regexAnySingleEscape = /[ -,\.\/:-@\[-\^`\{-~]/;
    var regexSingleEscape = /[ -,\.\/:-@\[\]\^`\{-~]/;
    var regexExcessiveSpaces = /(^|\\+)?(\\[A-F0-9]{1,6})\x20(?![a-fA-F0-9\x20])/g;
    var cssesc = function cssesc2(string, options) {
      options = merge(options, cssesc2.options);
      if (options.quotes != "single" && options.quotes != "double") {
        options.quotes = "single";
      }
      var quote = options.quotes == "double" ? '"' : "'";
      var isIdentifier = options.isIdentifier;
      var firstChar = string.charAt(0);
      var output = "";
      var counter = 0;
      var length = string.length;
      while (counter < length) {
        var character = string.charAt(counter++);
        var codePoint = character.charCodeAt();
        var value = void 0;
        if (codePoint < 32 || codePoint > 126) {
          if (codePoint >= 55296 && codePoint <= 56319 && counter < length) {
            var extra = string.charCodeAt(counter++);
            if ((extra & 64512) == 56320) {
              codePoint = ((codePoint & 1023) << 10) + (extra & 1023) + 65536;
            } else {
              counter--;
            }
          }
          value = "\\" + codePoint.toString(16).toUpperCase() + " ";
        } else {
          if (options.escapeEverything) {
            if (regexAnySingleEscape.test(character)) {
              value = "\\" + character;
            } else {
              value = "\\" + codePoint.toString(16).toUpperCase() + " ";
            }
          } else if (/[\t\n\f\r\x0B]/.test(character)) {
            value = "\\" + codePoint.toString(16).toUpperCase() + " ";
          } else if (character == "\\" || !isIdentifier && (character == '"' && quote == character || character == "'" && quote == character) || isIdentifier && regexSingleEscape.test(character)) {
            value = "\\" + character;
          } else {
            value = character;
          }
        }
        output += value;
      }
      if (isIdentifier) {
        if (/^-[-\d]/.test(output)) {
          output = "\\-" + output.slice(1);
        } else if (/\d/.test(firstChar)) {
          output = "\\3" + firstChar + " " + output.slice(1);
        }
      }
      output = output.replace(regexExcessiveSpaces, function($0, $1, $2) {
        if ($1 && $1.length % 2) {
          return $0;
        }
        return ($1 || "") + $2;
      });
      if (!isIdentifier && options.wrap) {
        return quote + output + quote;
      }
      return output;
    };
    cssesc.options = {
      "escapeEverything": false,
      "isIdentifier": false,
      "quotes": "single",
      "wrap": false
    };
    cssesc.version = "3.0.0";
    module2.exports = cssesc;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/className.js
var require_className = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/className.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = void 0;
    var _cssesc = _interopRequireDefault(require_cssesc());
    var _util = require_util();
    var _node = _interopRequireDefault(require_node());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _defineProperties(target, props) {
      for (var i = 0; i < props.length; i++) {
        var descriptor = props[i];
        descriptor.enumerable = descriptor.enumerable || false;
        descriptor.configurable = true;
        if ("value" in descriptor) descriptor.writable = true;
        Object.defineProperty(target, descriptor.key, descriptor);
      }
    }
    function _createClass(Constructor, protoProps, staticProps) {
      if (protoProps) _defineProperties(Constructor.prototype, protoProps);
      if (staticProps) _defineProperties(Constructor, staticProps);
      return Constructor;
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var ClassName = /* @__PURE__ */ (function(_Node) {
      _inheritsLoose(ClassName2, _Node);
      function ClassName2(opts) {
        var _this;
        _this = _Node.call(this, opts) || this;
        _this.type = _types.CLASS;
        _this._constructed = true;
        return _this;
      }
      var _proto = ClassName2.prototype;
      _proto.valueToString = function valueToString() {
        return "." + _Node.prototype.valueToString.call(this);
      };
      _createClass(ClassName2, [{
        key: "value",
        get: function get() {
          return this._value;
        },
        set: function set(v) {
          if (this._constructed) {
            var escaped = (0, _cssesc["default"])(v, {
              isIdentifier: true
            });
            if (escaped !== v) {
              (0, _util.ensureObject)(this, "raws");
              this.raws.value = escaped;
            } else if (this.raws) {
              delete this.raws.value;
            }
          }
          this._value = v;
        }
      }]);
      return ClassName2;
    })(_node["default"]);
    exports2["default"] = ClassName;
    module2.exports = exports2.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/comment.js
var require_comment = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/comment.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = void 0;
    var _node = _interopRequireDefault(require_node());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Comment = /* @__PURE__ */ (function(_Node) {
      _inheritsLoose(Comment2, _Node);
      function Comment2(opts) {
        var _this;
        _this = _Node.call(this, opts) || this;
        _this.type = _types.COMMENT;
        return _this;
      }
      return Comment2;
    })(_node["default"]);
    exports2["default"] = Comment;
    module2.exports = exports2.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/id.js
var require_id = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/id.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = void 0;
    var _node = _interopRequireDefault(require_node());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var ID = /* @__PURE__ */ (function(_Node) {
      _inheritsLoose(ID2, _Node);
      function ID2(opts) {
        var _this;
        _this = _Node.call(this, opts) || this;
        _this.type = _types.ID;
        return _this;
      }
      var _proto = ID2.prototype;
      _proto.valueToString = function valueToString() {
        return "#" + _Node.prototype.valueToString.call(this);
      };
      return ID2;
    })(_node["default"]);
    exports2["default"] = ID;
    module2.exports = exports2.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/namespace.js
var require_namespace = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/namespace.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = void 0;
    var _cssesc = _interopRequireDefault(require_cssesc());
    var _util = require_util();
    var _node = _interopRequireDefault(require_node());
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _defineProperties(target, props) {
      for (var i = 0; i < props.length; i++) {
        var descriptor = props[i];
        descriptor.enumerable = descriptor.enumerable || false;
        descriptor.configurable = true;
        if ("value" in descriptor) descriptor.writable = true;
        Object.defineProperty(target, descriptor.key, descriptor);
      }
    }
    function _createClass(Constructor, protoProps, staticProps) {
      if (protoProps) _defineProperties(Constructor.prototype, protoProps);
      if (staticProps) _defineProperties(Constructor, staticProps);
      return Constructor;
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Namespace = /* @__PURE__ */ (function(_Node) {
      _inheritsLoose(Namespace2, _Node);
      function Namespace2() {
        return _Node.apply(this, arguments) || this;
      }
      var _proto = Namespace2.prototype;
      _proto.qualifiedName = function qualifiedName(value) {
        if (this.namespace) {
          return this.namespaceString + "|" + value;
        } else {
          return value;
        }
      };
      _proto.valueToString = function valueToString() {
        return this.qualifiedName(_Node.prototype.valueToString.call(this));
      };
      _createClass(Namespace2, [{
        key: "namespace",
        get: function get() {
          return this._namespace;
        },
        set: function set(namespace) {
          if (namespace === true || namespace === "*" || namespace === "&") {
            this._namespace = namespace;
            if (this.raws) {
              delete this.raws.namespace;
            }
            return;
          }
          var escaped = (0, _cssesc["default"])(namespace, {
            isIdentifier: true
          });
          this._namespace = namespace;
          if (escaped !== namespace) {
            (0, _util.ensureObject)(this, "raws");
            this.raws.namespace = escaped;
          } else if (this.raws) {
            delete this.raws.namespace;
          }
        }
      }, {
        key: "ns",
        get: function get() {
          return this._namespace;
        },
        set: function set(namespace) {
          this.namespace = namespace;
        }
      }, {
        key: "namespaceString",
        get: function get() {
          if (this.namespace) {
            var ns = this.stringifyProperty("namespace");
            if (ns === true) {
              return "";
            } else {
              return ns;
            }
          } else {
            return "";
          }
        }
      }]);
      return Namespace2;
    })(_node["default"]);
    exports2["default"] = Namespace;
    module2.exports = exports2.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/tag.js
var require_tag = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/tag.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = void 0;
    var _namespace = _interopRequireDefault(require_namespace());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Tag = /* @__PURE__ */ (function(_Namespace) {
      _inheritsLoose(Tag2, _Namespace);
      function Tag2(opts) {
        var _this;
        _this = _Namespace.call(this, opts) || this;
        _this.type = _types.TAG;
        return _this;
      }
      return Tag2;
    })(_namespace["default"]);
    exports2["default"] = Tag;
    module2.exports = exports2.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/string.js
var require_string = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/string.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = void 0;
    var _node = _interopRequireDefault(require_node());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var String2 = /* @__PURE__ */ (function(_Node) {
      _inheritsLoose(String3, _Node);
      function String3(opts) {
        var _this;
        _this = _Node.call(this, opts) || this;
        _this.type = _types.STRING;
        return _this;
      }
      return String3;
    })(_node["default"]);
    exports2["default"] = String2;
    module2.exports = exports2.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/pseudo.js
var require_pseudo = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/pseudo.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = void 0;
    var _container = _interopRequireDefault(require_container());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Pseudo = /* @__PURE__ */ (function(_Container) {
      _inheritsLoose(Pseudo2, _Container);
      function Pseudo2(opts) {
        var _this;
        _this = _Container.call(this, opts) || this;
        _this.type = _types.PSEUDO;
        return _this;
      }
      var _proto = Pseudo2.prototype;
      _proto.toString = function toString() {
        var params = this.length ? "(" + this.map(String).join(",") + ")" : "";
        return [this.rawSpaceBefore, this.stringifyProperty("value"), params, this.rawSpaceAfter].join("");
      };
      return Pseudo2;
    })(_container["default"]);
    exports2["default"] = Pseudo;
    module2.exports = exports2.default;
  }
});

// util-shim.js
var require_util_shim = __commonJS({
  "util-shim.js"(exports2, module2) {
    module2.exports = {
      deprecate: function(fn) {
        return fn;
      }
    };
  }
});

// node_modules/util-deprecate/node.js
var require_node2 = __commonJS({
  "node_modules/util-deprecate/node.js"(exports2, module2) {
    module2.exports = require_util_shim().deprecate;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/attribute.js
var require_attribute = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/attribute.js"(exports2) {
    "use strict";
    exports2.__esModule = true;
    exports2.unescapeValue = unescapeValue;
    exports2["default"] = void 0;
    var _cssesc = _interopRequireDefault(require_cssesc());
    var _unesc = _interopRequireDefault(require_unesc());
    var _namespace = _interopRequireDefault(require_namespace());
    var _types = require_types();
    var _CSSESC_QUOTE_OPTIONS;
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _defineProperties(target, props) {
      for (var i = 0; i < props.length; i++) {
        var descriptor = props[i];
        descriptor.enumerable = descriptor.enumerable || false;
        descriptor.configurable = true;
        if ("value" in descriptor) descriptor.writable = true;
        Object.defineProperty(target, descriptor.key, descriptor);
      }
    }
    function _createClass(Constructor, protoProps, staticProps) {
      if (protoProps) _defineProperties(Constructor.prototype, protoProps);
      if (staticProps) _defineProperties(Constructor, staticProps);
      return Constructor;
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var deprecate = require_node2();
    var WRAPPED_IN_QUOTES = /^('|")([^]*)\1$/;
    var warnOfDeprecatedValueAssignment = deprecate(function() {
    }, "Assigning an attribute a value containing characters that might need to be escaped is deprecated. Call attribute.setValue() instead.");
    var warnOfDeprecatedQuotedAssignment = deprecate(function() {
    }, "Assigning attr.quoted is deprecated and has no effect. Assign to attr.quoteMark instead.");
    var warnOfDeprecatedConstructor = deprecate(function() {
    }, "Constructing an Attribute selector with a value without specifying quoteMark is deprecated. Note: The value should be unescaped now.");
    function unescapeValue(value) {
      var deprecatedUsage = false;
      var quoteMark = null;
      var unescaped = value;
      var m = unescaped.match(WRAPPED_IN_QUOTES);
      if (m) {
        quoteMark = m[1];
        unescaped = m[2];
      }
      unescaped = (0, _unesc["default"])(unescaped);
      if (unescaped !== value) {
        deprecatedUsage = true;
      }
      return {
        deprecatedUsage,
        unescaped,
        quoteMark
      };
    }
    function handleDeprecatedContructorOpts(opts) {
      if (opts.quoteMark !== void 0) {
        return opts;
      }
      if (opts.value === void 0) {
        return opts;
      }
      warnOfDeprecatedConstructor();
      var _unescapeValue = unescapeValue(opts.value), quoteMark = _unescapeValue.quoteMark, unescaped = _unescapeValue.unescaped;
      if (!opts.raws) {
        opts.raws = {};
      }
      if (opts.raws.value === void 0) {
        opts.raws.value = opts.value;
      }
      opts.value = unescaped;
      opts.quoteMark = quoteMark;
      return opts;
    }
    var Attribute = /* @__PURE__ */ (function(_Namespace) {
      _inheritsLoose(Attribute2, _Namespace);
      function Attribute2(opts) {
        var _this;
        if (opts === void 0) {
          opts = {};
        }
        _this = _Namespace.call(this, handleDeprecatedContructorOpts(opts)) || this;
        _this.type = _types.ATTRIBUTE;
        _this.raws = _this.raws || {};
        Object.defineProperty(_this.raws, "unquoted", {
          get: deprecate(function() {
            return _this.value;
          }, "attr.raws.unquoted is deprecated. Call attr.value instead."),
          set: deprecate(function() {
            return _this.value;
          }, "Setting attr.raws.unquoted is deprecated and has no effect. attr.value is unescaped by default now.")
        });
        _this._constructed = true;
        return _this;
      }
      var _proto = Attribute2.prototype;
      _proto.getQuotedValue = function getQuotedValue(options) {
        if (options === void 0) {
          options = {};
        }
        var quoteMark = this._determineQuoteMark(options);
        var cssescopts = CSSESC_QUOTE_OPTIONS[quoteMark];
        var escaped = (0, _cssesc["default"])(this._value, cssescopts);
        return escaped;
      };
      _proto._determineQuoteMark = function _determineQuoteMark(options) {
        return options.smart ? this.smartQuoteMark(options) : this.preferredQuoteMark(options);
      };
      _proto.setValue = function setValue(value, options) {
        if (options === void 0) {
          options = {};
        }
        this._value = value;
        this._quoteMark = this._determineQuoteMark(options);
        this._syncRawValue();
      };
      _proto.smartQuoteMark = function smartQuoteMark(options) {
        var v = this.value;
        var numSingleQuotes = v.replace(/[^']/g, "").length;
        var numDoubleQuotes = v.replace(/[^"]/g, "").length;
        if (numSingleQuotes + numDoubleQuotes === 0) {
          var escaped = (0, _cssesc["default"])(v, {
            isIdentifier: true
          });
          if (escaped === v) {
            return Attribute2.NO_QUOTE;
          } else {
            var pref = this.preferredQuoteMark(options);
            if (pref === Attribute2.NO_QUOTE) {
              var quote = this.quoteMark || options.quoteMark || Attribute2.DOUBLE_QUOTE;
              var opts = CSSESC_QUOTE_OPTIONS[quote];
              var quoteValue = (0, _cssesc["default"])(v, opts);
              if (quoteValue.length < escaped.length) {
                return quote;
              }
            }
            return pref;
          }
        } else if (numDoubleQuotes === numSingleQuotes) {
          return this.preferredQuoteMark(options);
        } else if (numDoubleQuotes < numSingleQuotes) {
          return Attribute2.DOUBLE_QUOTE;
        } else {
          return Attribute2.SINGLE_QUOTE;
        }
      };
      _proto.preferredQuoteMark = function preferredQuoteMark(options) {
        var quoteMark = options.preferCurrentQuoteMark ? this.quoteMark : options.quoteMark;
        if (quoteMark === void 0) {
          quoteMark = options.preferCurrentQuoteMark ? options.quoteMark : this.quoteMark;
        }
        if (quoteMark === void 0) {
          quoteMark = Attribute2.DOUBLE_QUOTE;
        }
        return quoteMark;
      };
      _proto._syncRawValue = function _syncRawValue() {
        var rawValue = (0, _cssesc["default"])(this._value, CSSESC_QUOTE_OPTIONS[this.quoteMark]);
        if (rawValue === this._value) {
          if (this.raws) {
            delete this.raws.value;
          }
        } else {
          this.raws.value = rawValue;
        }
      };
      _proto._handleEscapes = function _handleEscapes(prop, value) {
        if (this._constructed) {
          var escaped = (0, _cssesc["default"])(value, {
            isIdentifier: true
          });
          if (escaped !== value) {
            this.raws[prop] = escaped;
          } else {
            delete this.raws[prop];
          }
        }
      };
      _proto._spacesFor = function _spacesFor(name) {
        var attrSpaces = {
          before: "",
          after: ""
        };
        var spaces = this.spaces[name] || {};
        var rawSpaces = this.raws.spaces && this.raws.spaces[name] || {};
        return Object.assign(attrSpaces, spaces, rawSpaces);
      };
      _proto._stringFor = function _stringFor(name, spaceName, concat) {
        if (spaceName === void 0) {
          spaceName = name;
        }
        if (concat === void 0) {
          concat = defaultAttrConcat;
        }
        var attrSpaces = this._spacesFor(spaceName);
        return concat(this.stringifyProperty(name), attrSpaces);
      };
      _proto.offsetOf = function offsetOf(name) {
        var count = 1;
        var attributeSpaces = this._spacesFor("attribute");
        count += attributeSpaces.before.length;
        if (name === "namespace" || name === "ns") {
          return this.namespace ? count : -1;
        }
        if (name === "attributeNS") {
          return count;
        }
        count += this.namespaceString.length;
        if (this.namespace) {
          count += 1;
        }
        if (name === "attribute") {
          return count;
        }
        count += this.stringifyProperty("attribute").length;
        count += attributeSpaces.after.length;
        var operatorSpaces = this._spacesFor("operator");
        count += operatorSpaces.before.length;
        var operator = this.stringifyProperty("operator");
        if (name === "operator") {
          return operator ? count : -1;
        }
        count += operator.length;
        count += operatorSpaces.after.length;
        var valueSpaces = this._spacesFor("value");
        count += valueSpaces.before.length;
        var value = this.stringifyProperty("value");
        if (name === "value") {
          return value ? count : -1;
        }
        count += value.length;
        count += valueSpaces.after.length;
        var insensitiveSpaces = this._spacesFor("insensitive");
        count += insensitiveSpaces.before.length;
        if (name === "insensitive") {
          return this.insensitive ? count : -1;
        }
        return -1;
      };
      _proto.toString = function toString() {
        var _this2 = this;
        var selector = [this.rawSpaceBefore, "["];
        selector.push(this._stringFor("qualifiedAttribute", "attribute"));
        if (this.operator && (this.value || this.value === "")) {
          selector.push(this._stringFor("operator"));
          selector.push(this._stringFor("value"));
          selector.push(this._stringFor("insensitiveFlag", "insensitive", function(attrValue, attrSpaces) {
            if (attrValue.length > 0 && !_this2.quoted && attrSpaces.before.length === 0 && !(_this2.spaces.value && _this2.spaces.value.after)) {
              attrSpaces.before = " ";
            }
            return defaultAttrConcat(attrValue, attrSpaces);
          }));
        }
        selector.push("]");
        selector.push(this.rawSpaceAfter);
        return selector.join("");
      };
      _createClass(Attribute2, [{
        key: "quoted",
        get: function get() {
          var qm = this.quoteMark;
          return qm === "'" || qm === '"';
        },
        set: function set(value) {
          warnOfDeprecatedQuotedAssignment();
        }
        /**
         * returns a single (`'`) or double (`"`) quote character if the value is quoted.
         * returns `null` if the value is not quoted.
         * returns `undefined` if the quotation state is unknown (this can happen when
         * the attribute is constructed without specifying a quote mark.)
         */
      }, {
        key: "quoteMark",
        get: function get() {
          return this._quoteMark;
        },
        set: function set(quoteMark) {
          if (!this._constructed) {
            this._quoteMark = quoteMark;
            return;
          }
          if (this._quoteMark !== quoteMark) {
            this._quoteMark = quoteMark;
            this._syncRawValue();
          }
        }
      }, {
        key: "qualifiedAttribute",
        get: function get() {
          return this.qualifiedName(this.raws.attribute || this.attribute);
        }
      }, {
        key: "insensitiveFlag",
        get: function get() {
          return this.insensitive ? "i" : "";
        }
      }, {
        key: "value",
        get: function get() {
          return this._value;
        },
        set: function set(v) {
          if (this._constructed) {
            var _unescapeValue2 = unescapeValue(v), deprecatedUsage = _unescapeValue2.deprecatedUsage, unescaped = _unescapeValue2.unescaped, quoteMark = _unescapeValue2.quoteMark;
            if (deprecatedUsage) {
              warnOfDeprecatedValueAssignment();
            }
            if (unescaped === this._value && quoteMark === this._quoteMark) {
              return;
            }
            this._value = unescaped;
            this._quoteMark = quoteMark;
            this._syncRawValue();
          } else {
            this._value = v;
          }
        }
      }, {
        key: "attribute",
        get: function get() {
          return this._attribute;
        },
        set: function set(name) {
          this._handleEscapes("attribute", name);
          this._attribute = name;
        }
      }]);
      return Attribute2;
    })(_namespace["default"]);
    exports2["default"] = Attribute;
    Attribute.NO_QUOTE = null;
    Attribute.SINGLE_QUOTE = "'";
    Attribute.DOUBLE_QUOTE = '"';
    var CSSESC_QUOTE_OPTIONS = (_CSSESC_QUOTE_OPTIONS = {
      "'": {
        quotes: "single",
        wrap: true
      },
      '"': {
        quotes: "double",
        wrap: true
      }
    }, _CSSESC_QUOTE_OPTIONS[null] = {
      isIdentifier: true
    }, _CSSESC_QUOTE_OPTIONS);
    function defaultAttrConcat(attrValue, attrSpaces) {
      return "" + attrSpaces.before + attrValue + attrSpaces.after;
    }
  }
});

// node_modules/postcss-selector-parser/dist/selectors/universal.js
var require_universal = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/universal.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = void 0;
    var _namespace = _interopRequireDefault(require_namespace());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Universal = /* @__PURE__ */ (function(_Namespace) {
      _inheritsLoose(Universal2, _Namespace);
      function Universal2(opts) {
        var _this;
        _this = _Namespace.call(this, opts) || this;
        _this.type = _types.UNIVERSAL;
        _this.value = "*";
        return _this;
      }
      return Universal2;
    })(_namespace["default"]);
    exports2["default"] = Universal;
    module2.exports = exports2.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/combinator.js
var require_combinator = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/combinator.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = void 0;
    var _node = _interopRequireDefault(require_node());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Combinator = /* @__PURE__ */ (function(_Node) {
      _inheritsLoose(Combinator2, _Node);
      function Combinator2(opts) {
        var _this;
        _this = _Node.call(this, opts) || this;
        _this.type = _types.COMBINATOR;
        return _this;
      }
      return Combinator2;
    })(_node["default"]);
    exports2["default"] = Combinator;
    module2.exports = exports2.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/nesting.js
var require_nesting = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/nesting.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = void 0;
    var _node = _interopRequireDefault(require_node());
    var _types = require_types();
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _inheritsLoose(subClass, superClass) {
      subClass.prototype = Object.create(superClass.prototype);
      subClass.prototype.constructor = subClass;
      _setPrototypeOf(subClass, superClass);
    }
    function _setPrototypeOf(o, p) {
      _setPrototypeOf = Object.setPrototypeOf || function _setPrototypeOf2(o2, p2) {
        o2.__proto__ = p2;
        return o2;
      };
      return _setPrototypeOf(o, p);
    }
    var Nesting = /* @__PURE__ */ (function(_Node) {
      _inheritsLoose(Nesting2, _Node);
      function Nesting2(opts) {
        var _this;
        _this = _Node.call(this, opts) || this;
        _this.type = _types.NESTING;
        _this.value = "&";
        return _this;
      }
      return Nesting2;
    })(_node["default"]);
    exports2["default"] = Nesting;
    module2.exports = exports2.default;
  }
});

// node_modules/postcss-selector-parser/dist/sortAscending.js
var require_sortAscending = __commonJS({
  "node_modules/postcss-selector-parser/dist/sortAscending.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = sortAscending;
    function sortAscending(list) {
      return list.sort(function(a, b) {
        return a - b;
      });
    }
    module2.exports = exports2.default;
  }
});

// node_modules/postcss-selector-parser/dist/tokenTypes.js
var require_tokenTypes = __commonJS({
  "node_modules/postcss-selector-parser/dist/tokenTypes.js"(exports2) {
    "use strict";
    exports2.__esModule = true;
    exports2.combinator = exports2.word = exports2.comment = exports2.str = exports2.tab = exports2.newline = exports2.feed = exports2.cr = exports2.backslash = exports2.bang = exports2.slash = exports2.doubleQuote = exports2.singleQuote = exports2.space = exports2.greaterThan = exports2.pipe = exports2.equals = exports2.plus = exports2.caret = exports2.tilde = exports2.dollar = exports2.closeSquare = exports2.openSquare = exports2.closeParenthesis = exports2.openParenthesis = exports2.semicolon = exports2.colon = exports2.comma = exports2.at = exports2.asterisk = exports2.ampersand = void 0;
    var ampersand = 38;
    exports2.ampersand = ampersand;
    var asterisk = 42;
    exports2.asterisk = asterisk;
    var at = 64;
    exports2.at = at;
    var comma = 44;
    exports2.comma = comma;
    var colon = 58;
    exports2.colon = colon;
    var semicolon = 59;
    exports2.semicolon = semicolon;
    var openParenthesis = 40;
    exports2.openParenthesis = openParenthesis;
    var closeParenthesis = 41;
    exports2.closeParenthesis = closeParenthesis;
    var openSquare = 91;
    exports2.openSquare = openSquare;
    var closeSquare = 93;
    exports2.closeSquare = closeSquare;
    var dollar = 36;
    exports2.dollar = dollar;
    var tilde = 126;
    exports2.tilde = tilde;
    var caret = 94;
    exports2.caret = caret;
    var plus = 43;
    exports2.plus = plus;
    var equals = 61;
    exports2.equals = equals;
    var pipe = 124;
    exports2.pipe = pipe;
    var greaterThan = 62;
    exports2.greaterThan = greaterThan;
    var space = 32;
    exports2.space = space;
    var singleQuote = 39;
    exports2.singleQuote = singleQuote;
    var doubleQuote = 34;
    exports2.doubleQuote = doubleQuote;
    var slash = 47;
    exports2.slash = slash;
    var bang = 33;
    exports2.bang = bang;
    var backslash = 92;
    exports2.backslash = backslash;
    var cr = 13;
    exports2.cr = cr;
    var feed = 12;
    exports2.feed = feed;
    var newline = 10;
    exports2.newline = newline;
    var tab = 9;
    exports2.tab = tab;
    var str = singleQuote;
    exports2.str = str;
    var comment = -1;
    exports2.comment = comment;
    var word = -2;
    exports2.word = word;
    var combinator = -3;
    exports2.combinator = combinator;
  }
});

// node_modules/postcss-selector-parser/dist/tokenize.js
var require_tokenize = __commonJS({
  "node_modules/postcss-selector-parser/dist/tokenize.js"(exports2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = tokenize;
    exports2.FIELDS = void 0;
    var t = _interopRequireWildcard(require_tokenTypes());
    var _unescapable;
    var _wordDelimiters;
    function _getRequireWildcardCache() {
      if (typeof WeakMap !== "function") return null;
      var cache = /* @__PURE__ */ new WeakMap();
      _getRequireWildcardCache = function _getRequireWildcardCache2() {
        return cache;
      };
      return cache;
    }
    function _interopRequireWildcard(obj) {
      if (obj && obj.__esModule) {
        return obj;
      }
      if (obj === null || typeof obj !== "object" && typeof obj !== "function") {
        return { "default": obj };
      }
      var cache = _getRequireWildcardCache();
      if (cache && cache.has(obj)) {
        return cache.get(obj);
      }
      var newObj = {};
      var hasPropertyDescriptor = Object.defineProperty && Object.getOwnPropertyDescriptor;
      for (var key in obj) {
        if (Object.prototype.hasOwnProperty.call(obj, key)) {
          var desc = hasPropertyDescriptor ? Object.getOwnPropertyDescriptor(obj, key) : null;
          if (desc && (desc.get || desc.set)) {
            Object.defineProperty(newObj, key, desc);
          } else {
            newObj[key] = obj[key];
          }
        }
      }
      newObj["default"] = obj;
      if (cache) {
        cache.set(obj, newObj);
      }
      return newObj;
    }
    var unescapable = (_unescapable = {}, _unescapable[t.tab] = true, _unescapable[t.newline] = true, _unescapable[t.cr] = true, _unescapable[t.feed] = true, _unescapable);
    var wordDelimiters = (_wordDelimiters = {}, _wordDelimiters[t.space] = true, _wordDelimiters[t.tab] = true, _wordDelimiters[t.newline] = true, _wordDelimiters[t.cr] = true, _wordDelimiters[t.feed] = true, _wordDelimiters[t.ampersand] = true, _wordDelimiters[t.asterisk] = true, _wordDelimiters[t.bang] = true, _wordDelimiters[t.comma] = true, _wordDelimiters[t.colon] = true, _wordDelimiters[t.semicolon] = true, _wordDelimiters[t.openParenthesis] = true, _wordDelimiters[t.closeParenthesis] = true, _wordDelimiters[t.openSquare] = true, _wordDelimiters[t.closeSquare] = true, _wordDelimiters[t.singleQuote] = true, _wordDelimiters[t.doubleQuote] = true, _wordDelimiters[t.plus] = true, _wordDelimiters[t.pipe] = true, _wordDelimiters[t.tilde] = true, _wordDelimiters[t.greaterThan] = true, _wordDelimiters[t.equals] = true, _wordDelimiters[t.dollar] = true, _wordDelimiters[t.caret] = true, _wordDelimiters[t.slash] = true, _wordDelimiters);
    var hex = {};
    var hexChars = "0123456789abcdefABCDEF";
    for (i = 0; i < hexChars.length; i++) {
      hex[hexChars.charCodeAt(i)] = true;
    }
    var i;
    function consumeWord(css, start) {
      var next = start;
      var code;
      do {
        code = css.charCodeAt(next);
        if (wordDelimiters[code]) {
          return next - 1;
        } else if (code === t.backslash) {
          next = consumeEscape(css, next) + 1;
        } else {
          next++;
        }
      } while (next < css.length);
      return next - 1;
    }
    function consumeEscape(css, start) {
      var next = start;
      var code = css.charCodeAt(next + 1);
      if (unescapable[code]) {
      } else if (hex[code]) {
        var hexDigits = 0;
        do {
          next++;
          hexDigits++;
          code = css.charCodeAt(next + 1);
        } while (hex[code] && hexDigits < 6);
        if (hexDigits < 6 && code === t.space) {
          next++;
        }
      } else {
        next++;
      }
      return next;
    }
    var FIELDS = {
      TYPE: 0,
      START_LINE: 1,
      START_COL: 2,
      END_LINE: 3,
      END_COL: 4,
      START_POS: 5,
      END_POS: 6
    };
    exports2.FIELDS = FIELDS;
    function tokenize(input) {
      var tokens = [];
      var css = input.css.valueOf();
      var _css = css, length = _css.length;
      var offset = -1;
      var line = 1;
      var start = 0;
      var end = 0;
      var code, content, endColumn, endLine, escaped, escapePos, last, lines, next, nextLine, nextOffset, quote, tokenType;
      function unclosed(what, fix) {
        if (input.safe) {
          css += fix;
          next = css.length - 1;
        } else {
          throw input.error("Unclosed " + what, line, start - offset, start);
        }
      }
      while (start < length) {
        code = css.charCodeAt(start);
        if (code === t.newline) {
          offset = start;
          line += 1;
        }
        switch (code) {
          case t.space:
          case t.tab:
          case t.newline:
          case t.cr:
          case t.feed:
            next = start;
            do {
              next += 1;
              code = css.charCodeAt(next);
              if (code === t.newline) {
                offset = next;
                line += 1;
              }
            } while (code === t.space || code === t.newline || code === t.tab || code === t.cr || code === t.feed);
            tokenType = t.space;
            endLine = line;
            endColumn = next - offset - 1;
            end = next;
            break;
          case t.plus:
          case t.greaterThan:
          case t.tilde:
          case t.pipe:
            next = start;
            do {
              next += 1;
              code = css.charCodeAt(next);
            } while (code === t.plus || code === t.greaterThan || code === t.tilde || code === t.pipe);
            tokenType = t.combinator;
            endLine = line;
            endColumn = start - offset;
            end = next;
            break;
          // Consume these characters as single tokens.
          case t.asterisk:
          case t.ampersand:
          case t.bang:
          case t.comma:
          case t.equals:
          case t.dollar:
          case t.caret:
          case t.openSquare:
          case t.closeSquare:
          case t.colon:
          case t.semicolon:
          case t.openParenthesis:
          case t.closeParenthesis:
            next = start;
            tokenType = code;
            endLine = line;
            endColumn = start - offset;
            end = next + 1;
            break;
          case t.singleQuote:
          case t.doubleQuote:
            quote = code === t.singleQuote ? "'" : '"';
            next = start;
            do {
              escaped = false;
              next = css.indexOf(quote, next + 1);
              if (next === -1) {
                unclosed("quote", quote);
              }
              escapePos = next;
              while (css.charCodeAt(escapePos - 1) === t.backslash) {
                escapePos -= 1;
                escaped = !escaped;
              }
            } while (escaped);
            tokenType = t.str;
            endLine = line;
            endColumn = start - offset;
            end = next + 1;
            break;
          default:
            if (code === t.slash && css.charCodeAt(start + 1) === t.asterisk) {
              next = css.indexOf("*/", start + 2) + 1;
              if (next === 0) {
                unclosed("comment", "*/");
              }
              content = css.slice(start, next + 1);
              lines = content.split("\n");
              last = lines.length - 1;
              if (last > 0) {
                nextLine = line + last;
                nextOffset = next - lines[last].length;
              } else {
                nextLine = line;
                nextOffset = offset;
              }
              tokenType = t.comment;
              line = nextLine;
              endLine = nextLine;
              endColumn = next - nextOffset;
            } else if (code === t.slash) {
              next = start;
              tokenType = code;
              endLine = line;
              endColumn = start - offset;
              end = next + 1;
            } else {
              next = consumeWord(css, start);
              tokenType = t.word;
              endLine = line;
              endColumn = next - offset;
            }
            end = next + 1;
            break;
        }
        tokens.push([
          tokenType,
          // [0] Token type
          line,
          // [1] Starting line
          start - offset,
          // [2] Starting column
          endLine,
          // [3] Ending line
          endColumn,
          // [4] Ending column
          start,
          // [5] Start position / Source index
          end
          // [6] End position
        ]);
        if (nextOffset) {
          offset = nextOffset;
          nextOffset = null;
        }
        start = end;
      }
      return tokens;
    }
  }
});

// node_modules/postcss-selector-parser/dist/parser.js
var require_parser = __commonJS({
  "node_modules/postcss-selector-parser/dist/parser.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = void 0;
    var _root = _interopRequireDefault(require_root());
    var _selector = _interopRequireDefault(require_selector());
    var _className = _interopRequireDefault(require_className());
    var _comment = _interopRequireDefault(require_comment());
    var _id = _interopRequireDefault(require_id());
    var _tag = _interopRequireDefault(require_tag());
    var _string = _interopRequireDefault(require_string());
    var _pseudo = _interopRequireDefault(require_pseudo());
    var _attribute = _interopRequireWildcard(require_attribute());
    var _universal = _interopRequireDefault(require_universal());
    var _combinator = _interopRequireDefault(require_combinator());
    var _nesting = _interopRequireDefault(require_nesting());
    var _sortAscending = _interopRequireDefault(require_sortAscending());
    var _tokenize = _interopRequireWildcard(require_tokenize());
    var tokens = _interopRequireWildcard(require_tokenTypes());
    var types = _interopRequireWildcard(require_types());
    var _util = require_util();
    var _WHITESPACE_TOKENS;
    var _Object$assign;
    function _getRequireWildcardCache() {
      if (typeof WeakMap !== "function") return null;
      var cache = /* @__PURE__ */ new WeakMap();
      _getRequireWildcardCache = function _getRequireWildcardCache2() {
        return cache;
      };
      return cache;
    }
    function _interopRequireWildcard(obj) {
      if (obj && obj.__esModule) {
        return obj;
      }
      if (obj === null || typeof obj !== "object" && typeof obj !== "function") {
        return { "default": obj };
      }
      var cache = _getRequireWildcardCache();
      if (cache && cache.has(obj)) {
        return cache.get(obj);
      }
      var newObj = {};
      var hasPropertyDescriptor = Object.defineProperty && Object.getOwnPropertyDescriptor;
      for (var key in obj) {
        if (Object.prototype.hasOwnProperty.call(obj, key)) {
          var desc = hasPropertyDescriptor ? Object.getOwnPropertyDescriptor(obj, key) : null;
          if (desc && (desc.get || desc.set)) {
            Object.defineProperty(newObj, key, desc);
          } else {
            newObj[key] = obj[key];
          }
        }
      }
      newObj["default"] = obj;
      if (cache) {
        cache.set(obj, newObj);
      }
      return newObj;
    }
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    function _defineProperties(target, props) {
      for (var i = 0; i < props.length; i++) {
        var descriptor = props[i];
        descriptor.enumerable = descriptor.enumerable || false;
        descriptor.configurable = true;
        if ("value" in descriptor) descriptor.writable = true;
        Object.defineProperty(target, descriptor.key, descriptor);
      }
    }
    function _createClass(Constructor, protoProps, staticProps) {
      if (protoProps) _defineProperties(Constructor.prototype, protoProps);
      if (staticProps) _defineProperties(Constructor, staticProps);
      return Constructor;
    }
    var WHITESPACE_TOKENS = (_WHITESPACE_TOKENS = {}, _WHITESPACE_TOKENS[tokens.space] = true, _WHITESPACE_TOKENS[tokens.cr] = true, _WHITESPACE_TOKENS[tokens.feed] = true, _WHITESPACE_TOKENS[tokens.newline] = true, _WHITESPACE_TOKENS[tokens.tab] = true, _WHITESPACE_TOKENS);
    var WHITESPACE_EQUIV_TOKENS = Object.assign({}, WHITESPACE_TOKENS, (_Object$assign = {}, _Object$assign[tokens.comment] = true, _Object$assign));
    function tokenStart(token) {
      return {
        line: token[_tokenize.FIELDS.START_LINE],
        column: token[_tokenize.FIELDS.START_COL]
      };
    }
    function tokenEnd(token) {
      return {
        line: token[_tokenize.FIELDS.END_LINE],
        column: token[_tokenize.FIELDS.END_COL]
      };
    }
    function getSource(startLine, startColumn, endLine, endColumn) {
      return {
        start: {
          line: startLine,
          column: startColumn
        },
        end: {
          line: endLine,
          column: endColumn
        }
      };
    }
    function getTokenSource(token) {
      return getSource(token[_tokenize.FIELDS.START_LINE], token[_tokenize.FIELDS.START_COL], token[_tokenize.FIELDS.END_LINE], token[_tokenize.FIELDS.END_COL]);
    }
    function getTokenSourceSpan(startToken, endToken) {
      if (!startToken) {
        return void 0;
      }
      return getSource(startToken[_tokenize.FIELDS.START_LINE], startToken[_tokenize.FIELDS.START_COL], endToken[_tokenize.FIELDS.END_LINE], endToken[_tokenize.FIELDS.END_COL]);
    }
    function unescapeProp(node, prop) {
      var value = node[prop];
      if (typeof value !== "string") {
        return;
      }
      if (value.indexOf("\\") !== -1) {
        (0, _util.ensureObject)(node, "raws");
        node[prop] = (0, _util.unesc)(value);
        if (node.raws[prop] === void 0) {
          node.raws[prop] = value;
        }
      }
      return node;
    }
    function indexesOf(array, item) {
      var i = -1;
      var indexes = [];
      while ((i = array.indexOf(item, i + 1)) !== -1) {
        indexes.push(i);
      }
      return indexes;
    }
    function uniqs() {
      var list = Array.prototype.concat.apply([], arguments);
      return list.filter(function(item, i) {
        return i === list.indexOf(item);
      });
    }
    var Parser = /* @__PURE__ */ (function() {
      function Parser2(rule, options) {
        if (options === void 0) {
          options = {};
        }
        this.rule = rule;
        this.options = Object.assign({
          lossy: false,
          safe: false
        }, options);
        this.position = 0;
        this.css = typeof this.rule === "string" ? this.rule : this.rule.selector;
        this.tokens = (0, _tokenize["default"])({
          css: this.css,
          error: this._errorGenerator(),
          safe: this.options.safe
        });
        var rootSource = getTokenSourceSpan(this.tokens[0], this.tokens[this.tokens.length - 1]);
        this.root = new _root["default"]({
          source: rootSource
        });
        this.root.errorGenerator = this._errorGenerator();
        var selector = new _selector["default"]({
          source: {
            start: {
              line: 1,
              column: 1
            }
          }
        });
        this.root.append(selector);
        this.current = selector;
        this.loop();
      }
      var _proto = Parser2.prototype;
      _proto._errorGenerator = function _errorGenerator() {
        var _this = this;
        return function(message, errorOptions) {
          if (typeof _this.rule === "string") {
            return new Error(message);
          }
          return _this.rule.error(message, errorOptions);
        };
      };
      _proto.attribute = function attribute() {
        var attr = [];
        var startingToken = this.currToken;
        this.position++;
        while (this.position < this.tokens.length && this.currToken[_tokenize.FIELDS.TYPE] !== tokens.closeSquare) {
          attr.push(this.currToken);
          this.position++;
        }
        if (this.currToken[_tokenize.FIELDS.TYPE] !== tokens.closeSquare) {
          return this.expected("closing square bracket", this.currToken[_tokenize.FIELDS.START_POS]);
        }
        var len = attr.length;
        var node = {
          source: getSource(startingToken[1], startingToken[2], this.currToken[3], this.currToken[4]),
          sourceIndex: startingToken[_tokenize.FIELDS.START_POS]
        };
        if (len === 1 && !~[tokens.word].indexOf(attr[0][_tokenize.FIELDS.TYPE])) {
          return this.expected("attribute", attr[0][_tokenize.FIELDS.START_POS]);
        }
        var pos = 0;
        var spaceBefore = "";
        var commentBefore = "";
        var lastAdded = null;
        var spaceAfterMeaningfulToken = false;
        while (pos < len) {
          var token = attr[pos];
          var content = this.content(token);
          var next = attr[pos + 1];
          switch (token[_tokenize.FIELDS.TYPE]) {
            case tokens.space:
              spaceAfterMeaningfulToken = true;
              if (this.options.lossy) {
                break;
              }
              if (lastAdded) {
                (0, _util.ensureObject)(node, "spaces", lastAdded);
                var prevContent = node.spaces[lastAdded].after || "";
                node.spaces[lastAdded].after = prevContent + content;
                var existingComment = (0, _util.getProp)(node, "raws", "spaces", lastAdded, "after") || null;
                if (existingComment) {
                  node.raws.spaces[lastAdded].after = existingComment + content;
                }
              } else {
                spaceBefore = spaceBefore + content;
                commentBefore = commentBefore + content;
              }
              break;
            case tokens.asterisk:
              if (next[_tokenize.FIELDS.TYPE] === tokens.equals) {
                node.operator = content;
                lastAdded = "operator";
              } else if ((!node.namespace || lastAdded === "namespace" && !spaceAfterMeaningfulToken) && next) {
                if (spaceBefore) {
                  (0, _util.ensureObject)(node, "spaces", "attribute");
                  node.spaces.attribute.before = spaceBefore;
                  spaceBefore = "";
                }
                if (commentBefore) {
                  (0, _util.ensureObject)(node, "raws", "spaces", "attribute");
                  node.raws.spaces.attribute.before = spaceBefore;
                  commentBefore = "";
                }
                node.namespace = (node.namespace || "") + content;
                var rawValue = (0, _util.getProp)(node, "raws", "namespace") || null;
                if (rawValue) {
                  node.raws.namespace += content;
                }
                lastAdded = "namespace";
              }
              spaceAfterMeaningfulToken = false;
              break;
            case tokens.dollar:
              if (lastAdded === "value") {
                var oldRawValue = (0, _util.getProp)(node, "raws", "value");
                node.value += "$";
                if (oldRawValue) {
                  node.raws.value = oldRawValue + "$";
                }
                break;
              }
            // Falls through
            case tokens.caret:
              if (next[_tokenize.FIELDS.TYPE] === tokens.equals) {
                node.operator = content;
                lastAdded = "operator";
              }
              spaceAfterMeaningfulToken = false;
              break;
            case tokens.combinator:
              if (content === "~" && next[_tokenize.FIELDS.TYPE] === tokens.equals) {
                node.operator = content;
                lastAdded = "operator";
              }
              if (content !== "|") {
                spaceAfterMeaningfulToken = false;
                break;
              }
              if (next[_tokenize.FIELDS.TYPE] === tokens.equals) {
                node.operator = content;
                lastAdded = "operator";
              } else if (!node.namespace && !node.attribute) {
                node.namespace = true;
              }
              spaceAfterMeaningfulToken = false;
              break;
            case tokens.word:
              if (next && this.content(next) === "|" && attr[pos + 2] && attr[pos + 2][_tokenize.FIELDS.TYPE] !== tokens.equals && // this look-ahead probably fails with comment nodes involved.
              !node.operator && !node.namespace) {
                node.namespace = content;
                lastAdded = "namespace";
              } else if (!node.attribute || lastAdded === "attribute" && !spaceAfterMeaningfulToken) {
                if (spaceBefore) {
                  (0, _util.ensureObject)(node, "spaces", "attribute");
                  node.spaces.attribute.before = spaceBefore;
                  spaceBefore = "";
                }
                if (commentBefore) {
                  (0, _util.ensureObject)(node, "raws", "spaces", "attribute");
                  node.raws.spaces.attribute.before = commentBefore;
                  commentBefore = "";
                }
                node.attribute = (node.attribute || "") + content;
                var _rawValue = (0, _util.getProp)(node, "raws", "attribute") || null;
                if (_rawValue) {
                  node.raws.attribute += content;
                }
                lastAdded = "attribute";
              } else if (!node.value && node.value !== "" || lastAdded === "value" && !spaceAfterMeaningfulToken) {
                var _unescaped = (0, _util.unesc)(content);
                var _oldRawValue = (0, _util.getProp)(node, "raws", "value") || "";
                var oldValue = node.value || "";
                node.value = oldValue + _unescaped;
                node.quoteMark = null;
                if (_unescaped !== content || _oldRawValue) {
                  (0, _util.ensureObject)(node, "raws");
                  node.raws.value = (_oldRawValue || oldValue) + content;
                }
                lastAdded = "value";
              } else {
                var insensitive = content === "i" || content === "I";
                if ((node.value || node.value === "") && (node.quoteMark || spaceAfterMeaningfulToken)) {
                  node.insensitive = insensitive;
                  if (!insensitive || content === "I") {
                    (0, _util.ensureObject)(node, "raws");
                    node.raws.insensitiveFlag = content;
                  }
                  lastAdded = "insensitive";
                  if (spaceBefore) {
                    (0, _util.ensureObject)(node, "spaces", "insensitive");
                    node.spaces.insensitive.before = spaceBefore;
                    spaceBefore = "";
                  }
                  if (commentBefore) {
                    (0, _util.ensureObject)(node, "raws", "spaces", "insensitive");
                    node.raws.spaces.insensitive.before = commentBefore;
                    commentBefore = "";
                  }
                } else if (node.value || node.value === "") {
                  lastAdded = "value";
                  node.value += content;
                  if (node.raws.value) {
                    node.raws.value += content;
                  }
                }
              }
              spaceAfterMeaningfulToken = false;
              break;
            case tokens.str:
              if (!node.attribute || !node.operator) {
                return this.error("Expected an attribute followed by an operator preceding the string.", {
                  index: token[_tokenize.FIELDS.START_POS]
                });
              }
              var _unescapeValue = (0, _attribute.unescapeValue)(content), unescaped = _unescapeValue.unescaped, quoteMark = _unescapeValue.quoteMark;
              node.value = unescaped;
              node.quoteMark = quoteMark;
              lastAdded = "value";
              (0, _util.ensureObject)(node, "raws");
              node.raws.value = content;
              spaceAfterMeaningfulToken = false;
              break;
            case tokens.equals:
              if (!node.attribute) {
                return this.expected("attribute", token[_tokenize.FIELDS.START_POS], content);
              }
              if (node.value) {
                return this.error('Unexpected "=" found; an operator was already defined.', {
                  index: token[_tokenize.FIELDS.START_POS]
                });
              }
              node.operator = node.operator ? node.operator + content : content;
              lastAdded = "operator";
              spaceAfterMeaningfulToken = false;
              break;
            case tokens.comment:
              if (lastAdded) {
                if (spaceAfterMeaningfulToken || next && next[_tokenize.FIELDS.TYPE] === tokens.space || lastAdded === "insensitive") {
                  var lastComment = (0, _util.getProp)(node, "spaces", lastAdded, "after") || "";
                  var rawLastComment = (0, _util.getProp)(node, "raws", "spaces", lastAdded, "after") || lastComment;
                  (0, _util.ensureObject)(node, "raws", "spaces", lastAdded);
                  node.raws.spaces[lastAdded].after = rawLastComment + content;
                } else {
                  var lastValue = node[lastAdded] || "";
                  var rawLastValue = (0, _util.getProp)(node, "raws", lastAdded) || lastValue;
                  (0, _util.ensureObject)(node, "raws");
                  node.raws[lastAdded] = rawLastValue + content;
                }
              } else {
                commentBefore = commentBefore + content;
              }
              break;
            default:
              return this.error('Unexpected "' + content + '" found.', {
                index: token[_tokenize.FIELDS.START_POS]
              });
          }
          pos++;
        }
        unescapeProp(node, "attribute");
        unescapeProp(node, "namespace");
        this.newNode(new _attribute["default"](node));
        this.position++;
      };
      _proto.parseWhitespaceEquivalentTokens = function parseWhitespaceEquivalentTokens(stopPosition) {
        if (stopPosition < 0) {
          stopPosition = this.tokens.length;
        }
        var startPosition = this.position;
        var nodes = [];
        var space = "";
        var lastComment = void 0;
        do {
          if (WHITESPACE_TOKENS[this.currToken[_tokenize.FIELDS.TYPE]]) {
            if (!this.options.lossy) {
              space += this.content();
            }
          } else if (this.currToken[_tokenize.FIELDS.TYPE] === tokens.comment) {
            var spaces = {};
            if (space) {
              spaces.before = space;
              space = "";
            }
            lastComment = new _comment["default"]({
              value: this.content(),
              source: getTokenSource(this.currToken),
              sourceIndex: this.currToken[_tokenize.FIELDS.START_POS],
              spaces
            });
            nodes.push(lastComment);
          }
        } while (++this.position < stopPosition);
        if (space) {
          if (lastComment) {
            lastComment.spaces.after = space;
          } else if (!this.options.lossy) {
            var firstToken = this.tokens[startPosition];
            var lastToken = this.tokens[this.position - 1];
            nodes.push(new _string["default"]({
              value: "",
              source: getSource(firstToken[_tokenize.FIELDS.START_LINE], firstToken[_tokenize.FIELDS.START_COL], lastToken[_tokenize.FIELDS.END_LINE], lastToken[_tokenize.FIELDS.END_COL]),
              sourceIndex: firstToken[_tokenize.FIELDS.START_POS],
              spaces: {
                before: space,
                after: ""
              }
            }));
          }
        }
        return nodes;
      };
      _proto.convertWhitespaceNodesToSpace = function convertWhitespaceNodesToSpace(nodes, requiredSpace) {
        var _this2 = this;
        if (requiredSpace === void 0) {
          requiredSpace = false;
        }
        var space = "";
        var rawSpace = "";
        nodes.forEach(function(n) {
          var spaceBefore = _this2.lossySpace(n.spaces.before, requiredSpace);
          var rawSpaceBefore = _this2.lossySpace(n.rawSpaceBefore, requiredSpace);
          space += spaceBefore + _this2.lossySpace(n.spaces.after, requiredSpace && spaceBefore.length === 0);
          rawSpace += spaceBefore + n.value + _this2.lossySpace(n.rawSpaceAfter, requiredSpace && rawSpaceBefore.length === 0);
        });
        if (rawSpace === space) {
          rawSpace = void 0;
        }
        var result = {
          space,
          rawSpace
        };
        return result;
      };
      _proto.isNamedCombinator = function isNamedCombinator(position) {
        if (position === void 0) {
          position = this.position;
        }
        return this.tokens[position + 0] && this.tokens[position + 0][_tokenize.FIELDS.TYPE] === tokens.slash && this.tokens[position + 1] && this.tokens[position + 1][_tokenize.FIELDS.TYPE] === tokens.word && this.tokens[position + 2] && this.tokens[position + 2][_tokenize.FIELDS.TYPE] === tokens.slash;
      };
      _proto.namedCombinator = function namedCombinator() {
        if (this.isNamedCombinator()) {
          var nameRaw = this.content(this.tokens[this.position + 1]);
          var name = (0, _util.unesc)(nameRaw).toLowerCase();
          var raws = {};
          if (name !== nameRaw) {
            raws.value = "/" + nameRaw + "/";
          }
          var node = new _combinator["default"]({
            value: "/" + name + "/",
            source: getSource(this.currToken[_tokenize.FIELDS.START_LINE], this.currToken[_tokenize.FIELDS.START_COL], this.tokens[this.position + 2][_tokenize.FIELDS.END_LINE], this.tokens[this.position + 2][_tokenize.FIELDS.END_COL]),
            sourceIndex: this.currToken[_tokenize.FIELDS.START_POS],
            raws
          });
          this.position = this.position + 3;
          return node;
        } else {
          this.unexpected();
        }
      };
      _proto.combinator = function combinator() {
        var _this3 = this;
        if (this.content() === "|") {
          return this.namespace();
        }
        var nextSigTokenPos = this.locateNextMeaningfulToken(this.position);
        if (nextSigTokenPos < 0 || this.tokens[nextSigTokenPos][_tokenize.FIELDS.TYPE] === tokens.comma) {
          var nodes = this.parseWhitespaceEquivalentTokens(nextSigTokenPos);
          if (nodes.length > 0) {
            var last = this.current.last;
            if (last) {
              var _this$convertWhitespa = this.convertWhitespaceNodesToSpace(nodes), space = _this$convertWhitespa.space, rawSpace = _this$convertWhitespa.rawSpace;
              if (rawSpace !== void 0) {
                last.rawSpaceAfter += rawSpace;
              }
              last.spaces.after += space;
            } else {
              nodes.forEach(function(n) {
                return _this3.newNode(n);
              });
            }
          }
          return;
        }
        var firstToken = this.currToken;
        var spaceOrDescendantSelectorNodes = void 0;
        if (nextSigTokenPos > this.position) {
          spaceOrDescendantSelectorNodes = this.parseWhitespaceEquivalentTokens(nextSigTokenPos);
        }
        var node;
        if (this.isNamedCombinator()) {
          node = this.namedCombinator();
        } else if (this.currToken[_tokenize.FIELDS.TYPE] === tokens.combinator) {
          node = new _combinator["default"]({
            value: this.content(),
            source: getTokenSource(this.currToken),
            sourceIndex: this.currToken[_tokenize.FIELDS.START_POS]
          });
          this.position++;
        } else if (WHITESPACE_TOKENS[this.currToken[_tokenize.FIELDS.TYPE]]) {
        } else if (!spaceOrDescendantSelectorNodes) {
          this.unexpected();
        }
        if (node) {
          if (spaceOrDescendantSelectorNodes) {
            var _this$convertWhitespa2 = this.convertWhitespaceNodesToSpace(spaceOrDescendantSelectorNodes), _space = _this$convertWhitespa2.space, _rawSpace = _this$convertWhitespa2.rawSpace;
            node.spaces.before = _space;
            node.rawSpaceBefore = _rawSpace;
          }
        } else {
          var _this$convertWhitespa3 = this.convertWhitespaceNodesToSpace(spaceOrDescendantSelectorNodes, true), _space2 = _this$convertWhitespa3.space, _rawSpace2 = _this$convertWhitespa3.rawSpace;
          if (!_rawSpace2) {
            _rawSpace2 = _space2;
          }
          var spaces = {};
          var raws = {
            spaces: {}
          };
          if (_space2.endsWith(" ") && _rawSpace2.endsWith(" ")) {
            spaces.before = _space2.slice(0, _space2.length - 1);
            raws.spaces.before = _rawSpace2.slice(0, _rawSpace2.length - 1);
          } else if (_space2.startsWith(" ") && _rawSpace2.startsWith(" ")) {
            spaces.after = _space2.slice(1);
            raws.spaces.after = _rawSpace2.slice(1);
          } else {
            raws.value = _rawSpace2;
          }
          node = new _combinator["default"]({
            value: " ",
            source: getTokenSourceSpan(firstToken, this.tokens[this.position - 1]),
            sourceIndex: firstToken[_tokenize.FIELDS.START_POS],
            spaces,
            raws
          });
        }
        if (this.currToken && this.currToken[_tokenize.FIELDS.TYPE] === tokens.space) {
          node.spaces.after = this.optionalSpace(this.content());
          this.position++;
        }
        return this.newNode(node);
      };
      _proto.comma = function comma() {
        if (this.position === this.tokens.length - 1) {
          this.root.trailingComma = true;
          this.position++;
          return;
        }
        this.current._inferEndPosition();
        var selector = new _selector["default"]({
          source: {
            start: tokenStart(this.tokens[this.position + 1])
          }
        });
        this.current.parent.append(selector);
        this.current = selector;
        this.position++;
      };
      _proto.comment = function comment() {
        var current = this.currToken;
        this.newNode(new _comment["default"]({
          value: this.content(),
          source: getTokenSource(current),
          sourceIndex: current[_tokenize.FIELDS.START_POS]
        }));
        this.position++;
      };
      _proto.error = function error(message, opts) {
        throw this.root.error(message, opts);
      };
      _proto.missingBackslash = function missingBackslash() {
        return this.error("Expected a backslash preceding the semicolon.", {
          index: this.currToken[_tokenize.FIELDS.START_POS]
        });
      };
      _proto.missingParenthesis = function missingParenthesis() {
        return this.expected("opening parenthesis", this.currToken[_tokenize.FIELDS.START_POS]);
      };
      _proto.missingSquareBracket = function missingSquareBracket() {
        return this.expected("opening square bracket", this.currToken[_tokenize.FIELDS.START_POS]);
      };
      _proto.unexpected = function unexpected() {
        return this.error("Unexpected '" + this.content() + "'. Escaping special characters with \\ may help.", this.currToken[_tokenize.FIELDS.START_POS]);
      };
      _proto.namespace = function namespace() {
        var before = this.prevToken && this.content(this.prevToken) || true;
        if (this.nextToken[_tokenize.FIELDS.TYPE] === tokens.word) {
          this.position++;
          return this.word(before);
        } else if (this.nextToken[_tokenize.FIELDS.TYPE] === tokens.asterisk) {
          this.position++;
          return this.universal(before);
        }
      };
      _proto.nesting = function nesting() {
        if (this.nextToken) {
          var nextContent = this.content(this.nextToken);
          if (nextContent === "|") {
            this.position++;
            return;
          }
        }
        var current = this.currToken;
        this.newNode(new _nesting["default"]({
          value: this.content(),
          source: getTokenSource(current),
          sourceIndex: current[_tokenize.FIELDS.START_POS]
        }));
        this.position++;
      };
      _proto.parentheses = function parentheses() {
        var last = this.current.last;
        var unbalanced = 1;
        this.position++;
        if (last && last.type === types.PSEUDO) {
          var selector = new _selector["default"]({
            source: {
              start: tokenStart(this.tokens[this.position - 1])
            }
          });
          var cache = this.current;
          last.append(selector);
          this.current = selector;
          while (this.position < this.tokens.length && unbalanced) {
            if (this.currToken[_tokenize.FIELDS.TYPE] === tokens.openParenthesis) {
              unbalanced++;
            }
            if (this.currToken[_tokenize.FIELDS.TYPE] === tokens.closeParenthesis) {
              unbalanced--;
            }
            if (unbalanced) {
              this.parse();
            } else {
              this.current.source.end = tokenEnd(this.currToken);
              this.current.parent.source.end = tokenEnd(this.currToken);
              this.position++;
            }
          }
          this.current = cache;
        } else {
          var parenStart = this.currToken;
          var parenValue = "(";
          var parenEnd;
          while (this.position < this.tokens.length && unbalanced) {
            if (this.currToken[_tokenize.FIELDS.TYPE] === tokens.openParenthesis) {
              unbalanced++;
            }
            if (this.currToken[_tokenize.FIELDS.TYPE] === tokens.closeParenthesis) {
              unbalanced--;
            }
            parenEnd = this.currToken;
            parenValue += this.parseParenthesisToken(this.currToken);
            this.position++;
          }
          if (last) {
            last.appendToPropertyAndEscape("value", parenValue, parenValue);
          } else {
            this.newNode(new _string["default"]({
              value: parenValue,
              source: getSource(parenStart[_tokenize.FIELDS.START_LINE], parenStart[_tokenize.FIELDS.START_COL], parenEnd[_tokenize.FIELDS.END_LINE], parenEnd[_tokenize.FIELDS.END_COL]),
              sourceIndex: parenStart[_tokenize.FIELDS.START_POS]
            }));
          }
        }
        if (unbalanced) {
          return this.expected("closing parenthesis", this.currToken[_tokenize.FIELDS.START_POS]);
        }
      };
      _proto.pseudo = function pseudo() {
        var _this4 = this;
        var pseudoStr = "";
        var startingToken = this.currToken;
        while (this.currToken && this.currToken[_tokenize.FIELDS.TYPE] === tokens.colon) {
          pseudoStr += this.content();
          this.position++;
        }
        if (!this.currToken) {
          return this.expected(["pseudo-class", "pseudo-element"], this.position - 1);
        }
        if (this.currToken[_tokenize.FIELDS.TYPE] === tokens.word) {
          this.splitWord(false, function(first, length) {
            pseudoStr += first;
            _this4.newNode(new _pseudo["default"]({
              value: pseudoStr,
              source: getTokenSourceSpan(startingToken, _this4.currToken),
              sourceIndex: startingToken[_tokenize.FIELDS.START_POS]
            }));
            if (length > 1 && _this4.nextToken && _this4.nextToken[_tokenize.FIELDS.TYPE] === tokens.openParenthesis) {
              _this4.error("Misplaced parenthesis.", {
                index: _this4.nextToken[_tokenize.FIELDS.START_POS]
              });
            }
          });
        } else {
          return this.expected(["pseudo-class", "pseudo-element"], this.currToken[_tokenize.FIELDS.START_POS]);
        }
      };
      _proto.space = function space() {
        var content = this.content();
        if (this.position === 0 || this.prevToken[_tokenize.FIELDS.TYPE] === tokens.comma || this.prevToken[_tokenize.FIELDS.TYPE] === tokens.openParenthesis || this.current.nodes.every(function(node) {
          return node.type === "comment";
        })) {
          this.spaces = this.optionalSpace(content);
          this.position++;
        } else if (this.position === this.tokens.length - 1 || this.nextToken[_tokenize.FIELDS.TYPE] === tokens.comma || this.nextToken[_tokenize.FIELDS.TYPE] === tokens.closeParenthesis) {
          this.current.last.spaces.after = this.optionalSpace(content);
          this.position++;
        } else {
          this.combinator();
        }
      };
      _proto.string = function string() {
        var current = this.currToken;
        this.newNode(new _string["default"]({
          value: this.content(),
          source: getTokenSource(current),
          sourceIndex: current[_tokenize.FIELDS.START_POS]
        }));
        this.position++;
      };
      _proto.universal = function universal(namespace) {
        var nextToken = this.nextToken;
        if (nextToken && this.content(nextToken) === "|") {
          this.position++;
          return this.namespace();
        }
        var current = this.currToken;
        this.newNode(new _universal["default"]({
          value: this.content(),
          source: getTokenSource(current),
          sourceIndex: current[_tokenize.FIELDS.START_POS]
        }), namespace);
        this.position++;
      };
      _proto.splitWord = function splitWord(namespace, firstCallback) {
        var _this5 = this;
        var nextToken = this.nextToken;
        var word = this.content();
        while (nextToken && ~[tokens.dollar, tokens.caret, tokens.equals, tokens.word].indexOf(nextToken[_tokenize.FIELDS.TYPE])) {
          this.position++;
          var current = this.content();
          word += current;
          if (current.lastIndexOf("\\") === current.length - 1) {
            var next = this.nextToken;
            if (next && next[_tokenize.FIELDS.TYPE] === tokens.space) {
              word += this.requiredSpace(this.content(next));
              this.position++;
            }
          }
          nextToken = this.nextToken;
        }
        var hasClass = indexesOf(word, ".").filter(function(i) {
          var escapedDot = word[i - 1] === "\\";
          var isKeyframesPercent = /^\d+\.\d+%$/.test(word);
          return !escapedDot && !isKeyframesPercent;
        });
        var hasId = indexesOf(word, "#").filter(function(i) {
          return word[i - 1] !== "\\";
        });
        var interpolations = indexesOf(word, "#{");
        if (interpolations.length) {
          hasId = hasId.filter(function(hashIndex) {
            return !~interpolations.indexOf(hashIndex);
          });
        }
        var indices = (0, _sortAscending["default"])(uniqs([0].concat(hasClass, hasId)));
        indices.forEach(function(ind, i) {
          var index = indices[i + 1] || word.length;
          var value = word.slice(ind, index);
          if (i === 0 && firstCallback) {
            return firstCallback.call(_this5, value, indices.length);
          }
          var node;
          var current2 = _this5.currToken;
          var sourceIndex = current2[_tokenize.FIELDS.START_POS] + indices[i];
          var source = getSource(current2[1], current2[2] + ind, current2[3], current2[2] + (index - 1));
          if (~hasClass.indexOf(ind)) {
            var classNameOpts = {
              value: value.slice(1),
              source,
              sourceIndex
            };
            node = new _className["default"](unescapeProp(classNameOpts, "value"));
          } else if (~hasId.indexOf(ind)) {
            var idOpts = {
              value: value.slice(1),
              source,
              sourceIndex
            };
            node = new _id["default"](unescapeProp(idOpts, "value"));
          } else {
            var tagOpts = {
              value,
              source,
              sourceIndex
            };
            unescapeProp(tagOpts, "value");
            node = new _tag["default"](tagOpts);
          }
          _this5.newNode(node, namespace);
          namespace = null;
        });
        this.position++;
      };
      _proto.word = function word(namespace) {
        var nextToken = this.nextToken;
        if (nextToken && this.content(nextToken) === "|") {
          this.position++;
          return this.namespace();
        }
        return this.splitWord(namespace);
      };
      _proto.loop = function loop() {
        while (this.position < this.tokens.length) {
          this.parse(true);
        }
        this.current._inferEndPosition();
        return this.root;
      };
      _proto.parse = function parse(throwOnParenthesis) {
        switch (this.currToken[_tokenize.FIELDS.TYPE]) {
          case tokens.space:
            this.space();
            break;
          case tokens.comment:
            this.comment();
            break;
          case tokens.openParenthesis:
            this.parentheses();
            break;
          case tokens.closeParenthesis:
            if (throwOnParenthesis) {
              this.missingParenthesis();
            }
            break;
          case tokens.openSquare:
            this.attribute();
            break;
          case tokens.dollar:
          case tokens.caret:
          case tokens.equals:
          case tokens.word:
            this.word();
            break;
          case tokens.colon:
            this.pseudo();
            break;
          case tokens.comma:
            this.comma();
            break;
          case tokens.asterisk:
            this.universal();
            break;
          case tokens.ampersand:
            this.nesting();
            break;
          case tokens.slash:
          case tokens.combinator:
            this.combinator();
            break;
          case tokens.str:
            this.string();
            break;
          // These cases throw; no break needed.
          case tokens.closeSquare:
            this.missingSquareBracket();
          case tokens.semicolon:
            this.missingBackslash();
          default:
            this.unexpected();
        }
      };
      _proto.expected = function expected(description, index, found) {
        if (Array.isArray(description)) {
          var last = description.pop();
          description = description.join(", ") + " or " + last;
        }
        var an = /^[aeiou]/.test(description[0]) ? "an" : "a";
        if (!found) {
          return this.error("Expected " + an + " " + description + ".", {
            index
          });
        }
        return this.error("Expected " + an + " " + description + ', found "' + found + '" instead.', {
          index
        });
      };
      _proto.requiredSpace = function requiredSpace(space) {
        return this.options.lossy ? " " : space;
      };
      _proto.optionalSpace = function optionalSpace(space) {
        return this.options.lossy ? "" : space;
      };
      _proto.lossySpace = function lossySpace(space, required) {
        if (this.options.lossy) {
          return required ? " " : "";
        } else {
          return space;
        }
      };
      _proto.parseParenthesisToken = function parseParenthesisToken(token) {
        var content = this.content(token);
        if (token[_tokenize.FIELDS.TYPE] === tokens.space) {
          return this.requiredSpace(content);
        } else {
          return content;
        }
      };
      _proto.newNode = function newNode(node, namespace) {
        if (namespace) {
          if (/^ +$/.test(namespace)) {
            if (!this.options.lossy) {
              this.spaces = (this.spaces || "") + namespace;
            }
            namespace = true;
          }
          node.namespace = namespace;
          unescapeProp(node, "namespace");
        }
        if (this.spaces) {
          node.spaces.before = this.spaces;
          this.spaces = "";
        }
        return this.current.append(node);
      };
      _proto.content = function content(token) {
        if (token === void 0) {
          token = this.currToken;
        }
        return this.css.slice(token[_tokenize.FIELDS.START_POS], token[_tokenize.FIELDS.END_POS]);
      };
      _proto.locateNextMeaningfulToken = function locateNextMeaningfulToken(startPosition) {
        if (startPosition === void 0) {
          startPosition = this.position + 1;
        }
        var searchPosition = startPosition;
        while (searchPosition < this.tokens.length) {
          if (WHITESPACE_EQUIV_TOKENS[this.tokens[searchPosition][_tokenize.FIELDS.TYPE]]) {
            searchPosition++;
            continue;
          } else {
            return searchPosition;
          }
        }
        return -1;
      };
      _createClass(Parser2, [{
        key: "currToken",
        get: function get() {
          return this.tokens[this.position];
        }
      }, {
        key: "nextToken",
        get: function get() {
          return this.tokens[this.position + 1];
        }
      }, {
        key: "prevToken",
        get: function get() {
          return this.tokens[this.position - 1];
        }
      }]);
      return Parser2;
    })();
    exports2["default"] = Parser;
    module2.exports = exports2.default;
  }
});

// node_modules/postcss-selector-parser/dist/processor.js
var require_processor = __commonJS({
  "node_modules/postcss-selector-parser/dist/processor.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = void 0;
    var _parser = _interopRequireDefault(require_parser());
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    var Processor = /* @__PURE__ */ (function() {
      function Processor2(func, options) {
        this.func = func || function noop() {
        };
        this.funcRes = null;
        this.options = options;
      }
      var _proto = Processor2.prototype;
      _proto._shouldUpdateSelector = function _shouldUpdateSelector(rule, options) {
        if (options === void 0) {
          options = {};
        }
        var merged = Object.assign({}, this.options, options);
        if (merged.updateSelector === false) {
          return false;
        } else {
          return typeof rule !== "string";
        }
      };
      _proto._isLossy = function _isLossy(options) {
        if (options === void 0) {
          options = {};
        }
        var merged = Object.assign({}, this.options, options);
        if (merged.lossless === false) {
          return true;
        } else {
          return false;
        }
      };
      _proto._root = function _root(rule, options) {
        if (options === void 0) {
          options = {};
        }
        var parser = new _parser["default"](rule, this._parseOptions(options));
        return parser.root;
      };
      _proto._parseOptions = function _parseOptions(options) {
        return {
          lossy: this._isLossy(options)
        };
      };
      _proto._run = function _run(rule, options) {
        var _this = this;
        if (options === void 0) {
          options = {};
        }
        return new Promise(function(resolve, reject) {
          try {
            var root = _this._root(rule, options);
            Promise.resolve(_this.func(root)).then(function(transform) {
              var string = void 0;
              if (_this._shouldUpdateSelector(rule, options)) {
                string = root.toString();
                rule.selector = string;
              }
              return {
                transform,
                root,
                string
              };
            }).then(resolve, reject);
          } catch (e) {
            reject(e);
            return;
          }
        });
      };
      _proto._runSync = function _runSync(rule, options) {
        if (options === void 0) {
          options = {};
        }
        var root = this._root(rule, options);
        var transform = this.func(root);
        if (transform && typeof transform.then === "function") {
          throw new Error("Selector processor returned a promise to a synchronous call.");
        }
        var string = void 0;
        if (options.updateSelector && typeof rule !== "string") {
          string = root.toString();
          rule.selector = string;
        }
        return {
          transform,
          root,
          string
        };
      };
      _proto.ast = function ast(rule, options) {
        return this._run(rule, options).then(function(result) {
          return result.root;
        });
      };
      _proto.astSync = function astSync(rule, options) {
        return this._runSync(rule, options).root;
      };
      _proto.transform = function transform(rule, options) {
        return this._run(rule, options).then(function(result) {
          return result.transform;
        });
      };
      _proto.transformSync = function transformSync(rule, options) {
        return this._runSync(rule, options).transform;
      };
      _proto.process = function process(rule, options) {
        return this._run(rule, options).then(function(result) {
          return result.string || result.root.toString();
        });
      };
      _proto.processSync = function processSync(rule, options) {
        var result = this._runSync(rule, options);
        return result.string || result.root.toString();
      };
      return Processor2;
    })();
    exports2["default"] = Processor;
    module2.exports = exports2.default;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/constructors.js
var require_constructors = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/constructors.js"(exports2) {
    "use strict";
    exports2.__esModule = true;
    exports2.universal = exports2.tag = exports2.string = exports2.selector = exports2.root = exports2.pseudo = exports2.nesting = exports2.id = exports2.comment = exports2.combinator = exports2.className = exports2.attribute = void 0;
    var _attribute = _interopRequireDefault(require_attribute());
    var _className = _interopRequireDefault(require_className());
    var _combinator = _interopRequireDefault(require_combinator());
    var _comment = _interopRequireDefault(require_comment());
    var _id = _interopRequireDefault(require_id());
    var _nesting = _interopRequireDefault(require_nesting());
    var _pseudo = _interopRequireDefault(require_pseudo());
    var _root = _interopRequireDefault(require_root());
    var _selector = _interopRequireDefault(require_selector());
    var _string = _interopRequireDefault(require_string());
    var _tag = _interopRequireDefault(require_tag());
    var _universal = _interopRequireDefault(require_universal());
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    var attribute = function attribute2(opts) {
      return new _attribute["default"](opts);
    };
    exports2.attribute = attribute;
    var className = function className2(opts) {
      return new _className["default"](opts);
    };
    exports2.className = className;
    var combinator = function combinator2(opts) {
      return new _combinator["default"](opts);
    };
    exports2.combinator = combinator;
    var comment = function comment2(opts) {
      return new _comment["default"](opts);
    };
    exports2.comment = comment;
    var id = function id2(opts) {
      return new _id["default"](opts);
    };
    exports2.id = id;
    var nesting = function nesting2(opts) {
      return new _nesting["default"](opts);
    };
    exports2.nesting = nesting;
    var pseudo = function pseudo2(opts) {
      return new _pseudo["default"](opts);
    };
    exports2.pseudo = pseudo;
    var root = function root2(opts) {
      return new _root["default"](opts);
    };
    exports2.root = root;
    var selector = function selector2(opts) {
      return new _selector["default"](opts);
    };
    exports2.selector = selector;
    var string = function string2(opts) {
      return new _string["default"](opts);
    };
    exports2.string = string;
    var tag = function tag2(opts) {
      return new _tag["default"](opts);
    };
    exports2.tag = tag;
    var universal = function universal2(opts) {
      return new _universal["default"](opts);
    };
    exports2.universal = universal;
  }
});

// node_modules/postcss-selector-parser/dist/selectors/guards.js
var require_guards = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/guards.js"(exports2) {
    "use strict";
    exports2.__esModule = true;
    exports2.isNode = isNode;
    exports2.isPseudoElement = isPseudoElement;
    exports2.isPseudoClass = isPseudoClass;
    exports2.isContainer = isContainer;
    exports2.isNamespace = isNamespace;
    exports2.isUniversal = exports2.isTag = exports2.isString = exports2.isSelector = exports2.isRoot = exports2.isPseudo = exports2.isNesting = exports2.isIdentifier = exports2.isComment = exports2.isCombinator = exports2.isClassName = exports2.isAttribute = void 0;
    var _types = require_types();
    var _IS_TYPE;
    var IS_TYPE = (_IS_TYPE = {}, _IS_TYPE[_types.ATTRIBUTE] = true, _IS_TYPE[_types.CLASS] = true, _IS_TYPE[_types.COMBINATOR] = true, _IS_TYPE[_types.COMMENT] = true, _IS_TYPE[_types.ID] = true, _IS_TYPE[_types.NESTING] = true, _IS_TYPE[_types.PSEUDO] = true, _IS_TYPE[_types.ROOT] = true, _IS_TYPE[_types.SELECTOR] = true, _IS_TYPE[_types.STRING] = true, _IS_TYPE[_types.TAG] = true, _IS_TYPE[_types.UNIVERSAL] = true, _IS_TYPE);
    function isNode(node) {
      return typeof node === "object" && IS_TYPE[node.type];
    }
    function isNodeType(type, node) {
      return isNode(node) && node.type === type;
    }
    var isAttribute = isNodeType.bind(null, _types.ATTRIBUTE);
    exports2.isAttribute = isAttribute;
    var isClassName = isNodeType.bind(null, _types.CLASS);
    exports2.isClassName = isClassName;
    var isCombinator = isNodeType.bind(null, _types.COMBINATOR);
    exports2.isCombinator = isCombinator;
    var isComment = isNodeType.bind(null, _types.COMMENT);
    exports2.isComment = isComment;
    var isIdentifier = isNodeType.bind(null, _types.ID);
    exports2.isIdentifier = isIdentifier;
    var isNesting = isNodeType.bind(null, _types.NESTING);
    exports2.isNesting = isNesting;
    var isPseudo = isNodeType.bind(null, _types.PSEUDO);
    exports2.isPseudo = isPseudo;
    var isRoot = isNodeType.bind(null, _types.ROOT);
    exports2.isRoot = isRoot;
    var isSelector = isNodeType.bind(null, _types.SELECTOR);
    exports2.isSelector = isSelector;
    var isString = isNodeType.bind(null, _types.STRING);
    exports2.isString = isString;
    var isTag = isNodeType.bind(null, _types.TAG);
    exports2.isTag = isTag;
    var isUniversal = isNodeType.bind(null, _types.UNIVERSAL);
    exports2.isUniversal = isUniversal;
    function isPseudoElement(node) {
      return isPseudo(node) && node.value && (node.value.startsWith("::") || node.value.toLowerCase() === ":before" || node.value.toLowerCase() === ":after" || node.value.toLowerCase() === ":first-letter" || node.value.toLowerCase() === ":first-line");
    }
    function isPseudoClass(node) {
      return isPseudo(node) && !isPseudoElement(node);
    }
    function isContainer(node) {
      return !!(isNode(node) && node.walk);
    }
    function isNamespace(node) {
      return isAttribute(node) || isTag(node);
    }
  }
});

// node_modules/postcss-selector-parser/dist/selectors/index.js
var require_selectors = __commonJS({
  "node_modules/postcss-selector-parser/dist/selectors/index.js"(exports2) {
    "use strict";
    exports2.__esModule = true;
    var _types = require_types();
    Object.keys(_types).forEach(function(key) {
      if (key === "default" || key === "__esModule") return;
      if (key in exports2 && exports2[key] === _types[key]) return;
      exports2[key] = _types[key];
    });
    var _constructors = require_constructors();
    Object.keys(_constructors).forEach(function(key) {
      if (key === "default" || key === "__esModule") return;
      if (key in exports2 && exports2[key] === _constructors[key]) return;
      exports2[key] = _constructors[key];
    });
    var _guards = require_guards();
    Object.keys(_guards).forEach(function(key) {
      if (key === "default" || key === "__esModule") return;
      if (key in exports2 && exports2[key] === _guards[key]) return;
      exports2[key] = _guards[key];
    });
  }
});

// node_modules/postcss-selector-parser/dist/index.js
var require_dist = __commonJS({
  "node_modules/postcss-selector-parser/dist/index.js"(exports2, module2) {
    "use strict";
    exports2.__esModule = true;
    exports2["default"] = void 0;
    var _processor = _interopRequireDefault(require_processor());
    var selectors = _interopRequireWildcard(require_selectors());
    function _getRequireWildcardCache() {
      if (typeof WeakMap !== "function") return null;
      var cache = /* @__PURE__ */ new WeakMap();
      _getRequireWildcardCache = function _getRequireWildcardCache2() {
        return cache;
      };
      return cache;
    }
    function _interopRequireWildcard(obj) {
      if (obj && obj.__esModule) {
        return obj;
      }
      if (obj === null || typeof obj !== "object" && typeof obj !== "function") {
        return { "default": obj };
      }
      var cache = _getRequireWildcardCache();
      if (cache && cache.has(obj)) {
        return cache.get(obj);
      }
      var newObj = {};
      var hasPropertyDescriptor = Object.defineProperty && Object.getOwnPropertyDescriptor;
      for (var key in obj) {
        if (Object.prototype.hasOwnProperty.call(obj, key)) {
          var desc = hasPropertyDescriptor ? Object.getOwnPropertyDescriptor(obj, key) : null;
          if (desc && (desc.get || desc.set)) {
            Object.defineProperty(newObj, key, desc);
          } else {
            newObj[key] = obj[key];
          }
        }
      }
      newObj["default"] = obj;
      if (cache) {
        cache.set(obj, newObj);
      }
      return newObj;
    }
    function _interopRequireDefault(obj) {
      return obj && obj.__esModule ? obj : { "default": obj };
    }
    var parser = function parser2(processor) {
      return new _processor["default"](processor);
    };
    Object.assign(parser, selectors);
    delete parser.__esModule;
    var _default = parser;
    exports2["default"] = _default;
    module2.exports = exports2.default;
  }
});

// node_modules/@tailwindcss/typography/src/utils.js
var require_utils = __commonJS({
  "node_modules/@tailwindcss/typography/src/utils.js"(exports2, module2) {
    var parser = require_dist();
    var parseSelector = parser();
    function isObject(value) {
      return typeof value === "object" && value !== null;
    }
    function isPlainObject(value) {
      if (typeof value !== "object" || value === null) {
        return false;
      }
      if (Object.prototype.toString.call(value) !== "[object Object]") {
        return false;
      }
      if (Object.getPrototypeOf(value) === null) {
        return true;
      }
      let proto = value;
      while (Object.getPrototypeOf(proto) !== null) {
        proto = Object.getPrototypeOf(proto);
      }
      return Object.getPrototypeOf(value) === proto;
    }
    function merge(target, ...sources) {
      if (!sources.length) return target;
      const source = sources.shift();
      if (isObject(target) && isObject(source)) {
        for (const key in source) {
          if (Array.isArray(source[key])) {
            if (!target[key]) target[key] = [];
            source[key].forEach((item, index) => {
              if (isPlainObject(item) && isPlainObject(target[key][index])) {
                target[key][index] = merge(target[key][index], item);
              } else {
                target[key][index] = item;
              }
            });
          } else if (isPlainObject(source[key])) {
            if (!target[key]) target[key] = {};
            merge(target[key], source[key]);
          } else {
            target[key] = source[key];
          }
        }
      }
      return merge(target, ...sources);
    }
    function castArray(value) {
      return Array.isArray(value) ? value : [value];
    }
    module2.exports = {
      isObject,
      isPlainObject,
      merge,
      castArray,
      isUsableColor(color, values) {
        return isPlainObject(values) && color !== "gray" && values[600];
      },
      /**
       * @param {string} selector
       */
      commonTrailingPseudos(selector) {
        let ast = parseSelector.astSync(selector);
        let matrix = [];
        for (let [i, sel] of ast.nodes.entries()) {
          for (const [j, child] of [...sel.nodes].reverse().entries()) {
            if (child.type !== "pseudo" || !child.value.startsWith("::")) {
              break;
            }
            matrix[j] = matrix[j] || [];
            matrix[j][i] = child;
          }
        }
        let trailingPseudos = parser.selector();
        for (const pseudos of matrix) {
          if (!pseudos) {
            continue;
          }
          let values = new Set(pseudos.map((p) => p.value));
          if (values.size > 1) {
            break;
          }
          pseudos.forEach((pseudo) => pseudo.remove());
          trailingPseudos.prepend(pseudos[0]);
        }
        if (trailingPseudos.nodes.length) {
          return [trailingPseudos.toString(), ast.toString()];
        }
        return [null, selector];
      }
    };
  }
});

// node_modules/@tailwindcss/typography/src/index.js
var require_src = __commonJS({
  "node_modules/@tailwindcss/typography/src/index.js"(exports2, module2) {
    var plugin = require("tailwindcss/plugin");
    var styles = require_styles();
    var { commonTrailingPseudos, isObject, isPlainObject, merge, castArray } = require_utils();
    var computed = {
      // Reserved for future "magic properties", for example:
      // bulletColor: (color) => ({ 'ul > li::before': { backgroundColor: color } }),
    };
    function inWhere(selector, { className, modifier, prefix }) {
      let prefixedNot = prefix(`.not-${className}`).slice(1);
      let selectorPrefix = selector.startsWith(">") ? `${modifier === "DEFAULT" ? `.${className}` : `.${className}-${modifier}`} ` : "";
      let [trailingPseudo, rebuiltSelector] = commonTrailingPseudos(selector);
      if (trailingPseudo) {
        return `:where(${selectorPrefix}${rebuiltSelector}):not(:where([class~="${prefixedNot}"],[class~="${prefixedNot}"] *))${trailingPseudo}`;
      }
      return `:where(${selectorPrefix}${selector}):not(:where([class~="${prefixedNot}"],[class~="${prefixedNot}"] *))`;
    }
    function configToCss(config = {}, { target, className, modifier, prefix }) {
      function updateSelector(k, v) {
        if (target === "legacy") {
          return [k, v];
        }
        if (Array.isArray(v)) {
          return [k, v];
        }
        if (isObject(v)) {
          let nested = Object.values(v).some(isObject);
          if (nested) {
            return [
              inWhere(k, { className, modifier, prefix }),
              v,
              Object.fromEntries(Object.entries(v).map(([k2, v2]) => updateSelector(k2, v2)))
            ];
          }
          return [inWhere(k, { className, modifier, prefix }), v];
        }
        return [k, v];
      }
      return Object.fromEntries(
        Object.entries(
          merge(
            {},
            ...Object.keys(config).filter((key) => computed[key]).map((key) => computed[key](config[key])),
            ...castArray(config.css || {})
          )
        ).map(([k, v]) => updateSelector(k, v))
      );
    }
    module2.exports = plugin.withOptions(
      ({ className = "prose", target = "modern" } = {}) => {
        return function({ addVariant, addComponents, theme, prefix }) {
          let modifiers = theme("typography");
          let options = { className, prefix };
          for (let [name, ...selectors] of [
            ["headings", "h1", "h2", "h3", "h4", "h5", "h6", "th"],
            ["h1"],
            ["h2"],
            ["h3"],
            ["h4"],
            ["h5"],
            ["h6"],
            ["p"],
            ["a"],
            ["blockquote"],
            ["figure"],
            ["figcaption"],
            ["strong"],
            ["em"],
            ["kbd"],
            ["code"],
            ["pre"],
            ["ol"],
            ["ul"],
            ["li"],
            ["dl"],
            ["dt"],
            ["dd"],
            ["table"],
            ["thead"],
            ["tr"],
            ["th"],
            ["td"],
            ["img"],
            ["picture"],
            ["video"],
            ["hr"],
            ["lead", '[class~="lead"]']
          ]) {
            selectors = selectors.length === 0 ? [name] : selectors;
            let selector = target === "legacy" ? selectors.map((selector2) => `& ${selector2}`) : selectors.join(", ");
            addVariant(
              `${className}-${name}`,
              target === "legacy" ? selector : `& :is(${inWhere(selector, options)})`
            );
          }
          addComponents(
            Object.keys(modifiers).map((modifier) => ({
              [modifier === "DEFAULT" ? `.${className}` : `.${className}-${modifier}`]: configToCss(
                modifiers[modifier],
                {
                  target,
                  className,
                  modifier,
                  prefix
                }
              )
            }))
          );
        };
      },
      () => {
        return {
          theme: { typography: styles }
        };
      }
    );
  }
});

// bundle-entry.js
module.exports = require_src();
/*! Bundled license information:

cssesc/cssesc.js:
  (*! https://mths.be/cssesc v3.0.0 by @mathias *)
*/
