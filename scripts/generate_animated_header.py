# ==============================================================================
# generate_animated_header.py
# Generates animated banner SVG with typing and glowing neon effects
# ==============================================================================

svg_banner = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 200" width="100%" height="200">
  <defs>
    <style>
      @keyframes glowText {
        0%, 100% { filter: drop-shadow(0 0 4px rgba(255, 107, 107, 0.6)) drop-shadow(0 0 12px rgba(255, 75, 43, 0.4)); }
        50% { filter: drop-shadow(0 0 10px rgba(255, 107, 107, 0.9)) drop-shadow(0 0 25px rgba(255, 75, 43, 0.8)); }
      }
      @keyframes blink {
        0%, 100% { opacity: 1; }
        50% { opacity: 0; }
      }
      @keyframes pulseDot {
        0%, 100% { transform: scale(1); opacity: 0.8; }
        50% { transform: scale(1.3); opacity: 1; filter: drop-shadow(0 0 6px #00ffcc); }
      }
      @keyframes gradientShift {
        0% { stop-color: #ff416c; }
        50% { stop-color: #ff4b2b; }
        100% { stop-color: #ff416c; }
      }
      .glowing-title {
        animation: glowText 3s infinite ease-in-out;
      }
      .cursor {
        animation: blink 0.9s infinite;
      }
      .pulse-indicator {
        animation: pulseDot 2s infinite ease-in-out;
        transform-origin: 30px 158px;
      }
      text {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      }
    </style>

    <linearGradient id="header-grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0b0f19"/>
      <stop offset="50%" stop-color="#111827"/>
      <stop offset="100%" stop-color="#080c14"/>
    </linearGradient>

    <linearGradient id="fire-grad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#ff7675"/>
      <stop offset="50%" stop-color="#ff4b2b"/>
      <stop offset="100%" stop-color="#ffa502"/>
    </linearGradient>

    <linearGradient id="teal-grad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#00e5ff"/>
      <stop offset="100%" stop-color="#00ffa2"/>
    </linearGradient>
  </defs>

  <!-- Background Card -->
  <rect width="1000" height="200" rx="14" fill="url(#header-grad)" stroke="#1f293d" stroke-width="1.5"/>

  <!-- Subtle ambient glow background -->
  <circle cx="200" cy="100" r="140" fill="#ff4b2b" opacity="0.06" filter="blur(50px)"/>
  <circle cx="800" cy="100" r="140" fill="#00e5ff" opacity="0.05" filter="blur(60px)"/>

  <!-- Top Badge / Category -->
  <rect x="30" y="24" width="380" height="24" rx="12" fill="#1e1324" stroke="#8957e5" stroke-width="1"/>
  <text x="42" y="40" fill="#d2a8ff" font-size="10.5" font-weight="bold" letter-spacing="1">M.TECH MINOR PROJECT • ACADEMIC SESSION 2026–27</text>

  <!-- Main Glowing Title -->
  <g class="glowing-title">
    <text x="30" y="88" fill="url(#fire-grad)" font-size="28" font-weight="900" letter-spacing="0.5">
      Uttarakhand Wildfire Risk Analytics &amp; Early Warning System
    </text>
  </g>

  <!-- Subtitle with Terminal Style -->
  <text x="30" y="122" fill="#94a3b8" font-size="14" font-weight="500">
    Attentive Deep Learning (<tspan fill="#d2a8ff" font-weight="bold">TabNet</tspan>) • 5-Fold Tuned <tspan fill="#38bdf8" font-weight="bold">XGBoost</tspan> • <tspan fill="#4ade80" font-weight="bold">Open-Meteo REST API</tspan> • <tspan fill="#f59e0b" font-weight="bold">Shiny Web App</tspan>
  </text>
  <rect x="885" y="109" width="3" height="15" fill="#00e5ff" class="cursor"/>

  <!-- Status Bar / Metric Badges -->
  <rect x="30" y="146" width="940" height="34" rx="6" fill="#0d1526" stroke="#1e293b" stroke-width="1"/>
  <circle cx="46" cy="163" r="5" fill="#00ffa2" class="pulse-indicator"/>
  <text x="60" y="167" fill="#00ffa2" font-size="11" font-weight="bold">SYSTEM OPERATIONAL</text>

  <text x="210" y="167" fill="#64748b" font-size="11">|</text>
  <text x="230" y="167" fill="#f472b6" font-size="11" font-weight="bold">Peak Sensitivity: 83.50% Recall (TabNet)</text>

  <text x="510" y="167" fill="#64748b" font-size="11">|</text>
  <text x="530" y="167" fill="#38bdf8" font-size="11" font-weight="bold">Accuracy: 84.08% • Precision: 73.04% (XGBoost)</text>

  <text x="830" y="167" fill="#64748b" font-size="11">|</text>
  <text x="850" y="167" fill="#fbbf24" font-size="11" font-weight="bold">AUC: 0.9243 (RF)</text>
</svg>
"""

with open("outputs/plots/animated_header.svg", "w", encoding="utf-8") as f:
    f.write(svg_banner)

print("outputs/plots/animated_header.svg generated successfully!")

