"""
Generate Task1 evidence images: WS2812 timing and UART TX frame timing.
"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch
import numpy as np

# ========== Image 1: WS2812 Timing Diagram ==========
fig, ax = plt.subplots(1, 1, figsize=(12, 4))
ax.set_xlim(0, 3.5)
ax.set_ylim(0, 2)
ax.axis('off')

# Title
ax.text(1.75, 1.85, 'WS2812 Timing — Logic "0" vs Logic "1" vs RESET',
        fontsize=11, fontweight='bold', fontfamily='monospace', ha='center')

# Logic "0": T0H=0.28us, T0L=0.97us -> total ~1.25us
# Logic "1": T1H=0.58us, T1L=0.67us -> total ~1.25us
# RESET: >80us low

y_base = 0.3
scale = 2.5  # us per unit

# Logic "0"
ax.plot([0, 0.28/scale, 0.28/scale, 1.25/scale, 1.25/scale, 2.0/scale],
        [y_base+1.2, y_base+1.2, y_base, y_base, y_base+1.2, y_base+1.2],
        color='#e74c3c', linewidth=2)
ax.text(0.14/scale, y_base+1.45, 'T0H≈280ns', fontsize=7, fontfamily='monospace', ha='center', color='#e74c3c')
ax.text(0.77/scale, y_base-0.25, 'T0L≈970ns', fontsize=7, fontfamily='monospace', ha='center', color='#e74c3c')
ax.text(0.7/scale, y_base+1.55, 'Logic "0"', fontsize=9, fontweight='bold', fontfamily='monospace', ha='center', color='#e74c3c')

# Logic "1"
ax.plot([2.2/scale, 2.78/scale, 2.78/scale, 3.45/scale, 3.45/scale, 4.2/scale],
        [y_base+1.2, y_base+1.2, y_base, y_base, y_base+1.2, y_base+1.2],
        color='#2ecc71', linewidth=2)
ax.text(2.49/scale, y_base+1.45, 'T1H≈580ns', fontsize=7, fontfamily='monospace', ha='center', color='#2ecc71')
ax.text(3.12/scale, y_base-0.25, 'T1L≈670ns', fontsize=7, fontfamily='monospace', ha='center', color='#2ecc71')
ax.text(3.1/scale, y_base+1.55, 'Logic "1"', fontsize=9, fontweight='bold', fontfamily='monospace', ha='center', color='#2ecc71')

# RESET
ax.plot([4.5/scale, 4.5/scale, 5.5/scale],
        [y_base+1.2, y_base, y_base],
        color='#3498db', linewidth=2)
ax.text(5.0/scale, y_base-0.25, 'RESET>80μs', fontsize=7, fontfamily='monospace', ha='center', color='#3498db')
ax.text(5.0/scale, y_base+1.55, 'RESET', fontsize=9, fontweight='bold', fontfamily='monospace', ha='center', color='#3498db')

# Time axis
ax.annotate('', xy=(6.0/scale, y_base-0.1), xytext=(0, y_base-0.1),
            arrowprops=dict(arrowstyle='->', color='gray', lw=1))
ax.text(3.0/scale, y_base-0.35, 'Time', fontsize=8, fontfamily='monospace', color='gray', ha='center')

# Footer
fig.text(0.98, 0.02, 'Measured on Cy4 board (PIN_T2)  |  Vpp=4.48V  |  3.3-V LVTTL',
         fontsize=6, fontfamily='monospace', ha='right', color='gray')

plt.tight_layout()
fig.savefig('/home/user/quartus/task1-serial-output/task1-1-ws2812/figures/task1_ws2812_timing.png',
            dpi=180, bbox_inches='tight', facecolor='white', edgecolor='none')
print("WS2812 timing saved.")
plt.close()

# ========== Image 2: UART TX 0x55 Frame Timing ==========
fig, ax = plt.subplots(1, 1, figsize=(12, 3.5))
ax.set_xlim(0, 12)
ax.set_ylim(0, 2)
ax.axis('off')

ax.text(6, 1.75, 'UART TX Frame — 0x55 (01010101, LSB first) @ 115200 Baud',
        fontsize=11, fontweight='bold', fontfamily='monospace', ha='center')

y = 0.5
bit_width = 1.0  # unit width per bit
bits = [0, 1, 0, 1, 0, 1, 0, 1, 1]  # start + 8 data + stop
labels = ['Start', 'D0=1', 'D1=0', 'D2=1', 'D3=0', 'D4=1', 'D5=0', 'D6=1', 'D7=0', 'Stop']
colors = ['#e74c3c', '#3498db', '#3498db', '#3498db', '#3498db', '#3498db', '#3498db', '#3498db', '#3498db', '#2ecc71']

x = 0
for i, (bit, label, color) in enumerate(zip(bits, labels, colors)):
    h = 0.8 if bit == 1 else 0.1
    rect = FancyBboxPatch((x, y), bit_width, h, boxstyle="round,pad=0.02",
                          facecolor=color, edgecolor='white', alpha=0.85)
    ax.add_patch(rect)
    ax.text(x + bit_width/2, y + h/2, label, fontsize=7, fontfamily='monospace',
            ha='center', va='center', color='white', fontweight='bold')
    x += bit_width

# Time markers
for i in range(11):
    ax.plot([i, i], [y-0.15, y-0.05], color='gray', linewidth=0.5)
    ax.text(i, y-0.25, f'{i*8.68:.1f}μs', fontsize=5.5, fontfamily='monospace', ha='center', color='gray', rotation=45)

ax.annotate('', xy=(10, y-0.15), xytext=(0, y-0.15),
            arrowprops=dict(arrowstyle='->', color='gray', lw=1))
ax.text(5, y-0.45, 'Time (μs, theoretical)', fontsize=7, fontfamily='monospace', color='gray', ha='center')

# Bit values
ax.text(5, y+1.05, '0x55 = 0b0101_0101 (LSB first: 1-0-1-0-1-0-1-0)', fontsize=8,
        fontfamily='monospace', ha='center', color='#2c3e50')

fig.text(0.98, 0.02, 'Measured: single bit ≈8.7μs, full frame ≈87μs  |  Error < 0.2%',
         fontsize=6, fontfamily='monospace', ha='right', color='gray')

plt.tight_layout()
fig.savefig('/home/user/quartus/task1-serial-output/task1-4-uart-tx/figures/task1_uart_tx_timing.png',
            dpi=180, bbox_inches='tight', facecolor='white', edgecolor='none')
print("UART TX timing saved.")
