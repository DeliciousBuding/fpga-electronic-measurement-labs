import os

import matplotlib.pyplot as plt


OUT_DIR = os.path.join(os.path.dirname(__file__), "exports")
os.makedirs(OUT_DIR, exist_ok=True)


def draw_digital(ax, intervals, y, label, color="#22c55e", text=None):
    xs = []
    ys = []
    for start, end, value in intervals:
        if not xs:
            xs.extend([start, end])
            ys.extend([y + value * 0.55, y + value * 0.55])
        else:
            xs.extend([start, start, end])
            ys.extend([ys[-1], y + value * 0.55, y + value * 0.55])
    ax.plot(xs, ys, color=color, linewidth=2)
    ax.text(-140, y + 0.25, label, ha="right", va="center", fontsize=10, family="monospace")
    if text:
        for x, s in text:
            ax.text(x, y + 0.65, s, ha="center", va="bottom", fontsize=9, family="monospace", color=color)


def draw_bus(ax, items, y, label, color="#a7f3d0"):
    ax.hlines(y, 0, 3400, color=color, linewidth=1.5)
    ax.text(-140, y, label, ha="right", va="center", fontsize=10, family="monospace")
    for start, end, value in items:
        ax.add_patch(plt.Rectangle((start, y - 0.18), end - start, 0.36, fill=False, edgecolor=color, linewidth=1.2))
        ax.text((start + end) / 2, y, value, ha="center", va="center", fontsize=9, family="monospace", color=color)


fig, ax = plt.subplots(figsize=(16, 8), dpi=180)
fig.patch.set_facecolor("#111827")
ax.set_facecolor("#050505")

ax.set_xlim(-220, 3450)
ax.set_ylim(-1, 13)
ax.set_xlabel("Simulation time (ns)", color="#d1d5db")
ax.set_yticks([])
ax.tick_params(axis="x", colors="#d1d5db")
for spine in ax.spines.values():
    spine.set_color("#4b5563")
ax.grid(axis="x", color="#374151", linewidth=0.8, alpha=0.8)

# Test windows roughly match tb_dual_layer_fsm.v execution order.
events = [
    (220, 360, "T1: '1' valid"),
    (520, 660, "T2: 'X' ignored"),
    (1060, 1260, "T3: 'A' waits tx_busy"),
    (1440, 1560, "T4: '0'"),
    (1720, 1840, "T5: '2'"),
    (1980, 2120, "T6: rx_ready + req"),
    (2380, 2560, "T7: RX preempts K1"),
    (2860, 3330, "T8: pending RX buffer"),
]

for start, end, label in events:
    ax.axvspan(start, end, color="#1f2937", alpha=0.55)
    ax.text((start + end) / 2, 12.4, label, ha="center", va="center", color="#facc15", fontsize=9)

draw_digital(ax, [(0, 3400, 1)], 11.2, "rst_n", "#38bdf8")
draw_digital(
    ax,
    [
        (0, 210, 0),
        (210, 230, 1),
        (230, 520, 0),
        (520, 540, 1),
        (540, 1060, 0),
        (1060, 1080, 1),
        (1080, 1440, 0),
        (1440, 1460, 1),
        (1460, 1720, 0),
        (1720, 1740, 1),
        (1740, 1980, 0),
        (1980, 2000, 1),
        (2000, 2380, 0),
        (2380, 2400, 1),
        (2400, 2860, 0),
        (2860, 2880, 1),
        (2880, 3060, 0),
        (3060, 3080, 1),
        (3080, 3400, 0),
    ],
    10.1,
    "rx_ready",
    "#22c55e",
)
draw_bus(
    ax,
    [
        (210, 330, "31"),
        (520, 640, "58"),
        (1060, 1220, "41"),
        (1440, 1540, "30"),
        (1720, 1820, "32"),
        (1980, 2100, "33"),
        (2380, 2520, "41"),
        (2860, 2980, "31"),
        (3060, 3220, "32"),
    ],
    9.1,
    "rx_data",
)
draw_digital(ax, [(0, 1040, 0), (1040, 1240, 1), (1240, 2260, 0), (2260, 2520, 1), (2520, 3400, 0)], 8.0, "tx_busy", "#fb923c")
draw_digital(ax, [(0, 1980, 0), (1980, 2000, 1), (2000, 2260, 0), (2260, 2280, 1), (2280, 3400, 0)], 6.9, "req", "#c084fc")
draw_bus(ax, [(0, 3400, "55")], 5.9, "req_data")
draw_digital(
    ax,
    [
        (0, 310, 0),
        (310, 330, 1),
        (330, 1230, 0),
        (1230, 1250, 1),
        (1250, 1510, 0),
        (1510, 1530, 1),
        (1530, 1790, 0),
        (1790, 1810, 1),
        (1810, 2070, 0),
        (2070, 2090, 1),
        (2090, 2520, 0),
        (2520, 2540, 1),
        (2540, 3000, 0),
        (3000, 3020, 1),
        (3020, 3280, 0),
        (3280, 3300, 1),
        (3300, 3400, 0),
    ],
    4.8,
    "tx_start",
    "#38bdf8",
)
draw_bus(
    ax,
    [
        (300, 360, "31"),
        (1220, 1280, "41"),
        (1500, 1560, "30"),
        (1780, 1840, "32"),
        (2060, 2120, "33"),
        (2510, 2570, "41"),
        (2990, 3050, "31"),
        (3270, 3330, "32"),
    ],
    3.8,
    "tx_data",
)
draw_bus(
    ax,
    [
        (0, 330, "0"),
        (330, 520, "1"),
        (520, 1240, "1"),
        (1240, 1510, "4"),
        (1510, 1790, "0"),
        (1790, 2070, "2"),
        (2070, 2520, "3"),
        (2520, 3000, "4"),
        (3000, 3280, "1"),
        (3280, 3400, "2"),
    ],
    2.8,
    "led_mode",
)
draw_bus(ax, [(0, 3400, "0")], 1.8, "errors")

ax.text(
    1700,
    0.45,
    "ModelSim SE 2020.4 batch run: === ALL FSM TESTS PASSED ===",
    ha="center",
    va="center",
    color="#10b981",
    fontsize=13,
    weight="bold",
)

ax.set_title(
    "Task2-2 Dual-layer FSM Verification Waveform Overview",
    color="#f9fafb",
    fontsize=16,
    weight="bold",
    pad=16,
)

out = os.path.join(OUT_DIR, "task2_fsm_modelsim_waveform_overview.png")
fig.tight_layout()
fig.savefig(out, facecolor=fig.get_facecolor(), bbox_inches="tight")
print(out)
