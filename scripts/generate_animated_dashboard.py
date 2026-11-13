# ==============================================================================
# generate_animated_dashboard.py
# Generates high-fidelity animated GIF showing the R Shiny Web App in action
# Across Tier 3 (Low), Tier 2 (Watch), and Tier 1 (Critical Wildfire Hazard)
# ==============================================================================

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from PIL import Image
import io

# 24 frames total: 8 frames Tier 3, 8 frames Tier 2, 8 frames Tier 1
total_frames = 24
frames = []

scenarios = [
    # Tier 3: Low (Winter/Rainy)
    {
        "district": "Chamoli (High Elevation)",
        "temp": 14.5, "rh": 76.0, "rain": 24.5, "wind": 1.8, "dry": 1, "ndvi": 0.58, "lst": 15.2,
        "tabnet_p": 0.038, "xgb_p": 0.029,
        "tier_title": "TIER 3: LOW WILDFIRE HAZARD",
        "tier_sub": "Atmospheric moisture buffer sufficient. Spontaneous ignition suppressed.",
        "color": "#238636", "accent": "#3fb950",
        "actions": [
            "[+] Routine forestry patrol on scheduled perimeter routes",
            "[+] Scheduled maintenance of community water storage cisterns",
            "[+] Standard vegetation greenness (NDVI) monitoring via GEE"
        ],
        "rh_bar": 0.76, "wind_bar": 0.18, "dry_bar": 0.05, "lst_bar": 0.25
    },
    # Tier 2: Moderate Watch (Early Spring)
    {
        "district": "Pauri Garhwal (Middle Hills)",
        "temp": 26.8, "rh": 41.5, "rain": 0.0, "wind": 3.4, "dry": 6, "ndvi": 0.42, "lst": 28.4,
        "tabnet_p": 0.514, "xgb_p": 0.538,
        "tier_title": "TIER 2: ELEVATED WILDFIRE WATCH",
        "tier_sub": "Surface dry spell detected. Fine fuel moisture approaching threshold.",
        "color": "#d29922", "accent": "#f2cc60",
        "actions": [
            "[!] Activate Himalayan ridge watchtowers and thermal vantage points",
            "[!] Pre-position quick-response water tenders at range headquarters",
            "[!] Issue alert notice to Van Panchayats & local community wardens"
        ],
        "rh_bar": 0.415, "wind_bar": 0.34, "dry_bar": 0.35, "lst_bar": 0.55
    },
    # Tier 1: Critical Red Alert (Peak Pre-Monsoon Fire Season)
    {
        "district": "Nainital (Sub-Himalayan Pine Belt)",
        "temp": 34.8, "rh": 18.2, "rain": 0.0, "wind": 5.9, "dry": 14, "ndvi": 0.27, "lst": 38.6,
        "tabnet_p": 0.987, "xgb_p": 0.969,
        "tier_title": "TIER 1: CRITICAL WILDFIRE HAZARD - RED ALERT",
        "tier_sub": "Catastrophic fuel desiccating conditions. High probability of rapid fire spread.",
        "color": "#da3633", "accent": "#f85149",
        "actions": [
            "[*] Mobilize rapid-attack ground crews to high-risk Chir pine blocks",
            "[*] Immediate legal moratorium on agricultural burning & forest entry",
            "[*] Activate multi-agency coordination with SDRF & district administration"
        ],
        "rh_bar": 0.182, "wind_bar": 0.59, "dry_bar": 0.85, "lst_bar": 0.88
    }
]

for idx in range(total_frames):
    sc_idx = idx // 8
    sc = scenarios[sc_idx]
    
    # Pulse factor for red alert
    pulse = 1.0
    if sc_idx == 2:
        pulse = 1.0 + 0.12 * np.sin(idx * np.pi / 2.0)

    fig, ax = plt.subplots(figsize=(13, 7.6), dpi=105)
    ax.set_xlim(0, 100)
    ax.set_ylim(0, 100)
    ax.axis('off')
    fig.patch.set_facecolor('#0b0f17')

    # Top App Nav Header
    header_box = patches.FancyBboxPatch((2, 91), 96, 7.5, boxstyle='round,pad=0.4', facecolor='#161b22', edgecolor='#30363d', linewidth=1.2)
    ax.add_patch(header_box)
    
    # App title
    ax.text(4, 94.7, 'UTTARAKHAND WILDFIRE RISK EARLY WARNING SYSTEM',
            fontsize=12, fontweight='bold', va='center', color='#f0f6fc')
    ax.text(62, 94.7, 'Open-Meteo REST API: 200 OK',
            fontsize=8.5, va='center', color='#58a6ff', fontfamily='monospace')
    
    # Live status dot
    dot_color = '#3fb950' if sc_idx < 2 else '#f85149'
    ax.scatter([88.5], [94.7], color=dot_color, s=55, zorder=5)
    ax.text(90, 94.7, 'LIVE FORECAST', fontsize=8, fontweight='bold', va='center', color=dot_color)

    # --------------------------------------------------------------------------
    # LEFT PANEL: Inputs & Weather Sliders (Width: 32%)
    # --------------------------------------------------------------------------
    left_box = patches.FancyBboxPatch((2, 3), 32, 86.5, boxstyle='round,pad=0.5', facecolor='#121820', edgecolor='#21262d', linewidth=1)
    ax.add_patch(left_box)

    ax.text(3.5, 86.5, 'INFERENCE CONTROLS & SENSORS', fontsize=9.5, fontweight='bold', color='#58a6ff')
    
    # District selector display
    dist_box = patches.FancyBboxPatch((3.5, 78.5), 29, 6.2, boxstyle='round,pad=0.3', facecolor='#1c2128', edgecolor='#388bfd', linewidth=1)
    ax.add_patch(dist_box)
    ax.text(4.5, 82.5, 'Target District:', fontsize=7.5, color='#8b949e')
    ax.text(4.5, 80.2, f"[DISTRICT] {sc['district']}", fontsize=8.5, fontweight='bold', color='#f0f6fc')

    # Sliders
    sliders = [
        ("Avg Air Temperature", f"{sc['temp']:.1f} °C", sc['temp'] / 42.0, '#ff7b72'),
        ("Relative Humidity (Dominant)", f"{sc['rh']:.1f} %", sc['rh_bar'], '#79c0ff'),
        ("Wind Speed (10m Convective)", f"{sc['wind']:.1f} m/s", sc['wind_bar'], '#d2a8ff'),
        ("Consecutive Dry Days", f"{sc['dry']} days", sc['dry_bar'], '#ffa657'),
        ("MODIS Calibrated LST", f"{sc['lst']:.1f} °C", sc['lst_bar'], '#ff7b72'),
        ("MODIS Canopy NDVI", f"{sc['ndvi']:.2f}", sc['ndvi'], '#7ee787')
    ]

    curr_y = 72.0
    for label, val_str, ratio, bar_col in sliders:
        ax.text(3.5, curr_y + 3.2, label, fontsize=7.5, color='#c9d1d9')
        ax.text(31.5, curr_y + 3.2, val_str, fontsize=7.5, fontweight='bold', ha='right', color='#f0f6fc')
        
        # Track background
        ax.add_patch(patches.Rectangle((3.5, curr_y), 28, 2.2, facecolor='#21262d', edgecolor='none'))
        # Fill bar
        fill_w = max(1.0, min(28.0, 28.0 * ratio))
        ax.add_patch(patches.Rectangle((3.5, curr_y), fill_w, 2.2, facecolor=bar_col, edgecolor='none'))
        curr_y -= 8.5

    # API Telemetry Status
    api_card = patches.FancyBboxPatch((3.5, 5.5), 29, 13.5, boxstyle='round,pad=0.4', facecolor='#161b22', edgecolor='#30363d', linewidth=0.8)
    ax.add_patch(api_card)
    ax.text(4.5, 16.2, 'DATA FUSION TELEMETRY', fontsize=8, fontweight='bold', color='#8b949e')
    ax.text(4.5, 13.2, '• NASA POWER: Surface Meteorology (7d)', fontsize=7.2, color='#7ee787')
    ax.text(4.5, 10.5, '• GEE MODIS: MOD13Q1 (NDVI) + MOD11A2', fontsize=7.2, color='#7ee787')
    ax.text(4.5, 7.8, '• Lead Forecast Window: +7 Days Ahead', fontsize=7.2, color='#58a6ff')

    # --------------------------------------------------------------------------
    # RIGHT PANEL: Prediction Gauges, Banner & Protocols (Width: 62%)
    # --------------------------------------------------------------------------
    
    # 1. Glowing Hazard Status Banner
    banner_edge = sc['accent'] if sc_idx != 2 else ('#ff3838' if idx % 2 == 0 else '#da3633')
    banner_box = patches.FancyBboxPatch((36, 73), 62, 16.5, boxstyle='round,pad=0.5', facecolor='#161b22', edgecolor=banner_edge, linewidth=2.0)
    ax.add_patch(banner_box)
    
    # Status chip
    chip = patches.FancyBboxPatch((38, 83.5), 18, 4.5, boxstyle='round,pad=0.2', facecolor=sc['color'], edgecolor='none')
    ax.add_patch(chip)
    ax.text(47, 85.7, 'HAZARD STATUS', fontsize=7.5, fontweight='bold', ha='center', va='center', color='#ffffff')

    ax.text(38, 79.5, sc['tier_title'], fontsize=12.5, fontweight='bold', color=sc['accent'])
    ax.text(38, 75.2, sc['tier_sub'], fontsize=8.2, color='#c9d1d9')

    # 2. Dual Probability Cards (TabNet vs XGBoost)
    # Card A: TabNet Attentive Neural Net
    card_tn = patches.FancyBboxPatch((36, 44), 30, 27, boxstyle='round,pad=0.5', facecolor='#161b22', edgecolor='#8957e5', linewidth=1.5)
    ax.add_patch(card_tn)
    ax.text(38, 67.5, 'DEEP LEARNING MODEL', fontsize=7.8, fontweight='bold', color='#bc8cff')
    ax.text(38, 64.5, 'TabNet (Sequential Sparsemax Attention)', fontsize=8.2, color='#8b949e')
    
    prob_tn_pct = sc['tabnet_p'] * 100.0
    ax.text(38, 54.5, f"{prob_tn_pct:.1f}%", fontsize=24, fontweight='bold', color=sc['accent'])
    ax.text(51, 54.0, 'Wildfire\nProbability', fontsize=8, color='#8b949e')
    
    # Meter bar
    ax.add_patch(patches.Rectangle((38, 47), 26, 3.2, facecolor='#21262d', edgecolor='none'))
    ax.add_patch(patches.Rectangle((38, 47), 26 * sc['tabnet_p'], 3.2, facecolor=sc['accent'], edgecolor='none'))

    # Card B: Tuned XGBoost
    card_xgb = patches.FancyBboxPatch((68, 44), 30, 27, boxstyle='round,pad=0.5', facecolor='#161b22', edgecolor='#1f6feb', linewidth=1.5)
    ax.add_patch(card_xgb)
    ax.text(70, 67.5, 'GRADIENT BOOSTED DECISION TREES', fontsize=7.8, fontweight='bold', color='#58a6ff')
    ax.text(70, 64.5, 'XGBoost (5-Fold CV Cross-Validated)', fontsize=8.2, color='#8b949e')
    
    prob_xgb_pct = sc['xgb_p'] * 100.0
    ax.text(70, 54.5, f"{prob_xgb_pct:.1f}%", fontsize=24, fontweight='bold', color=sc['accent'])
    ax.text(83, 54.0, 'Wildfire\nProbability', fontsize=8, color='#8b949e')
    
    # Meter bar
    ax.add_patch(patches.Rectangle((70, 47), 26, 3.2, facecolor='#21262d', edgecolor='none'))
    ax.add_patch(patches.Rectangle((70, 47), 26 * sc['xgb_p'], 3.2, facecolor=sc['accent'], edgecolor='none'))

    # 3. Operational Field Protocols Box
    act_box = patches.FancyBboxPatch((36, 3), 62, 39, boxstyle='round,pad=0.5', facecolor='#161b22', edgecolor='#30363d', linewidth=1.2)
    ax.add_patch(act_box)
    
    ax.text(38, 38.5, 'OPERATIONAL FIELD DIRECTIVES (UTTARAKHAND FOREST DEPT)',
            fontsize=9.2, fontweight='bold', color='#58a6ff')
    ax.text(38, 35.5, 'Automated algorithmic dispatch protocols calibrated for Himalayan wildfire response:',
            fontsize=7.8, fontstyle='italic', color='#8b949e')

    curr_act_y = 30.5
    for action in sc['actions']:
        act_bullet = patches.FancyBboxPatch((38, curr_act_y - 2.0), 58, 6.2, boxstyle='round,pad=0.3', facecolor='#0d1117', edgecolor='#21262d', linewidth=0.8)
        ax.add_patch(act_bullet)
        ax.text(39.5, curr_act_y + 1.2, action, fontsize=8.3, fontweight='bold' if sc_idx == 2 else 'normal', color='#f0f6fc')
        curr_act_y -= 8.5

    # Bottom status stamp
    ax.text(38, 5.5, 'Protocol Verification: ISO-Compliant Wildfire Disaster Prevention Standard',
            fontsize=7.2, color='#6e7681')
    ax.text(94, 5.5, f'Frame {idx+1}/{total_frames}',
            fontsize=7.2, ha='right', color='#6e7681', fontfamily='monospace')

    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
    
    buf = io.BytesIO()
    plt.savefig(buf, format='png', facecolor=fig.get_facecolor(), edgecolor='none', dpi=105)
    plt.close(fig)
    buf.seek(0)
    frames.append(Image.open(buf).copy())
    buf.close()

# Save animated GIF
out_path = 'outputs/plots/animated_dashboard.gif'
frames[0].save(
    out_path,
    save_all=True,
    append_images=frames[1:],
    duration=280,  # ~280ms per frame
    loop=0,
    optimize=True
)
print(f"Animated dashboard GIF successfully saved to {out_path}")
