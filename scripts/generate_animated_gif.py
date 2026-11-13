# ==============================================================================
# generate_animated_gif.py
# Generates animated GIF of the system architecture with flowing particles
# ==============================================================================

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from PIL import Image
import io

n_frames = 20

frames = []

for frame_idx in range(n_frames):
    fig, ax = plt.subplots(figsize=(14, 8), dpi=100)
    ax.set_xlim(0, 100)
    ax.set_ylim(0, 100)
    ax.axis('off')
    fig.patch.set_facecolor('#0d1117')

    # Title
    ax.text(50, 96, 'UTTARAKHAND WILDFIRE EARLY WARNING SYSTEM',
            fontsize=15, fontweight='bold', ha='center', va='center', color='#58a6ff')
    ax.text(50, 92, 'Multi-Source Telemetry Ingestion • Attentive Deep Learning (TabNet) • Real-Time Alert Dashboard',
            fontsize=9.5, fontstyle='italic', ha='center', va='center', color='#8b949e')

    # Layer 1: Data Ingestion
    box1 = patches.FancyBboxPatch((3, 70), 94, 18, boxstyle='round,pad=0.8', facecolor='#161b22', edgecolor='#1f6feb', linewidth=1.5)
    ax.add_patch(box1)
    ax.text(5, 85, 'LAYER 1: MULTI-SOURCE SATELLITE & METEOROLOGICAL TELEMETRY (2019–2024)',
            fontsize=10.5, fontweight='bold', color='#58a6ff')

    sources = [
        ('NASA FIRMS Thermal Hotspots\n• MODIS 1km & VIIRS 375m\n• Label: fire_occurred', 5, 72, 28, '#0d419d'),
        ('NASA POWER Surface Meteorology\n• Temp, Humidity, Rain, Wind\n• max_consec_dry_days', 36, 72, 28, '#1b4728'),
        ('Google Earth Engine (MODIS)\n• 250m NDVI (Fuel Moisture)\n• 1km LST (Surface Temp °C)', 67, 72, 28, '#4d2c00')
    ]
    for title, x, y, w, ec in sources:
        sb = patches.FancyBboxPatch((x, y), w, 11, boxstyle='round,pad=0.5', facecolor='#0d1117', edgecolor=ec, linewidth=1.2)
        ax.add_patch(sb)
        ax.text(x + w/2, y + 5.5, title, fontsize=8.5, ha='center', va='center', color='#c9d1d9')

    # Layer 2: Preprocessing
    box2 = patches.FancyBboxPatch((3, 49), 94, 16, boxstyle='round,pad=0.8', facecolor='#161b22', edgecolor='#d29922', linewidth=1.5)
    ax.add_patch(box2)
    ax.text(5, 62, 'LAYER 2: DATA FUSION, MEDIAN IMPUTATION & ROSE CLASS BALANCING',
            fontsize=10.5, fontweight='bold', color='#e3b341')

    prep_steps = [
        ('Spatiotemporal Join\n(District, Week)', 5, 51, 21),
        ('Median Imputation\n& Min-Max Scaling', 28.5, 51, 21),
        ('Stratified Split\n80% Train / 20% Test', 52, 51, 21),
        ('ROSE Class Balancing\nBalanced: 50% / 50%', 75.5, 51, 21)
    ]
    for title, x, y, w in prep_steps:
        sb = patches.FancyBboxPatch((x, y), w, 9, boxstyle='round,pad=0.4', facecolor='#0d1117', edgecolor='#6e4000', linewidth=1)
        ax.add_patch(sb)
        ax.text(x + w/2, y + 4.5, title, fontsize=8, ha='center', va='center', color='#c9d1d9')

    # Layer 3: Models
    box3 = patches.FancyBboxPatch((3, 27), 94, 17, boxstyle='round,pad=0.8', facecolor='#161b22', edgecolor='#8957e5', linewidth=1.5)
    ax.add_patch(box3)
    ax.text(5, 41, 'LAYER 3: MULTI-MODEL BENCHMARK & ATTENTIVE DEEP LEARNING (TABNET)',
            fontsize=10.5, fontweight='bold', color='#bc8cff')

    models = [
        ('Logistic Regression\n(GLM Baseline)\nAUC: 0.9115', 5, 29, 21, '#30363d', '#8b949e'),
        ('Random Forest\n(200 Trees)\nAUC: 0.9243 (PEAK)', 28.5, 29, 21, '#238636', '#3fb950'),
        ('XGBoost (Tuned)\nAcc: 84.08% (PEAK)\nPrec: 73.04% (PEAK)', 52, 29, 21, '#1f6feb', '#58a6ff'),
        ('TabNet Neural Net\nRecall: 83.50% (PEAK)\nF1: 0.7713 (PEAK)', 75.5, 29, 21, '#a371f7', '#d2a8ff')
    ]
    for title, x, y, w, ec, tc in models:
        is_tn = 'TabNet' in title
        lw = 2.2 if is_tn else 1.2
        sb = patches.FancyBboxPatch((x, y), w, 10.5, boxstyle='round,pad=0.5', facecolor='#0d1117', edgecolor=ec, linewidth=lw)
        ax.add_patch(sb)
        ax.text(x + w/2, y + 5.25, title, fontsize=8.2, ha='center', va='center', color=tc, fontweight='bold' if is_tn else 'normal')

    # Layer 4: Real-Time Operational Deployment
    box4 = patches.FancyBboxPatch((3, 5), 94, 17, boxstyle='round,pad=0.8', facecolor='#161b22', edgecolor='#da3633', linewidth=1.5)
    ax.add_patch(box4)
    ax.text(5, 19, 'LAYER 4: EXPLAINABLE AI (SHAP) & REAL-TIME WEB DASHBOARD DEPLOYMENT',
            fontsize=10.5, fontweight='bold', color='#f85149')

    deploy_boxes = [
        ('Dual Explainable AI (XAI)\n• TreeSHAP Exact Decomposition\n• TabNet Sparsemax Attention Masks\n• Dominant: Relative Humidity (38.5%)', 5, 7, 28, '#8b949e'),
        ('Open-Meteo REST API\n• Live 7-Day Numerical Weather Feed\n• Automated Lead Horizon Scoring\n• HTTP_200_OK Real-Time Pipeline', 36, 7, 28, '#58a6ff'),
        ('Interactive Web Dashboard\n• Tier 1 Critical / Tier 2 Watch / Tier 3 Low\n• Interactive Sliders for Stress-Testing\n• Localhost: http://127.0.0.1:7860', 67, 7, 28, '#f85149')
    ]
    for title, x, y, w, tc in deploy_boxes:
        sb = patches.FancyBboxPatch((x, y), w, 10, boxstyle='round,pad=0.5', facecolor='#0d1117', edgecolor='#30363d', linewidth=1)
        ax.add_patch(sb)
        ax.text(x + w/2, y + 5, title, fontsize=8.2, ha='center', va='center', color=tc)

    # Animated Flow Particles (moving downwards along connecting arrows)
    t = frame_idx / n_frames
    
    # Path 1: 1 -> 2 (x=50, y from 70 to 49)
    y_p1 = 70 - t * 21
    ax.plot([50, 50], [70, 49], color='#30363d', linestyle='--', linewidth=1.5)
    ax.plot(50, y_p1, marker='o', markersize=7, color='#58a6ff', alpha=0.9)

    # Path 2: 2 -> 3 (x=50, y from 49 to 27)
    y_p2 = 49 - t * 22
    ax.plot([50, 50], [49, 27], color='#30363d', linestyle='--', linewidth=1.5)
    ax.plot(50, y_p2, marker='o', markersize=7, color='#e3b341', alpha=0.9)

    # Path 3: 3 -> 4 (x=50, y from 27 to 5)
    y_p3 = 27 - t * 22
    ax.plot([50, 50], [27, 5], color='#30363d', linestyle='--', linewidth=1.5)
    ax.plot(50, y_p3, marker='o', markersize=8, color='#d2a8ff', alpha=0.9)

    # Lateral streaming particles into TabNet (x from 50 to 86 at y=34)
    x_tn = 50 + t * 36
    ax.plot([50, 86], [34, 34], color='#8957e5', linestyle=':', linewidth=1.2, alpha=0.6)
    ax.plot(x_tn, 34, marker='o', markersize=6, color='#bc8cff', alpha=0.85)

    # Lateral streaming particles from TabNet to Web App (y=17 to 12 at x=86)
    y_app = 27 - t * 15
    ax.plot([86, 86], [27, 12], color='#da3633', linestyle=':', linewidth=1.2, alpha=0.6)
    ax.plot(86, y_app, marker='o', markersize=6, color='#f85149', alpha=0.85)

    # Pulsing status ring
    pulse_size = 5 + 4 * np.sin(2 * np.pi * t)
    ax.plot(94, 94, marker='o', markersize=pulse_size, color='#238636', alpha=0.8)

    buf = io.BytesIO()
    plt.tight_layout()
    plt.savefig(buf, format='png', facecolor=fig.get_facecolor(), edgecolor='none', bbox_inches='tight')
    plt.close(fig)
    buf.seek(0)
    frames.append(Image.open(buf))

frames[0].save(
    'outputs/plots/animated_architecture.gif',
    save_all=True,
    append_images=frames[1:],
    duration=100,
    loop=0,
    optimize=True
)

print('Animated GIF generated successfully: outputs/plots/animated_architecture.gif')
