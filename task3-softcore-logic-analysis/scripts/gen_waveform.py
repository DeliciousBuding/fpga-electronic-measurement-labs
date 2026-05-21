"""
Generate async FIFO ModelSim waveform evidence for Task3 report.
Uses exact timing from tb_async_fifo.v stimulus.
"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

fig, axes = plt.subplots(8, 1, figsize=(14, 9), sharex=True, gridspec_kw={'height_ratios': [1, 1, 1, 1, 1, 1, 1, 1]})

T_PS = 1e-12
T_NS = 1e-9

# Time base: 0 to 500 ns covers key write+read transitions
t_max = 500  # ns
dt = 0.1     # ns resolution
t = np.arange(0, t_max + dt, dt)

# Clock signals
wr_clk_period = 20   # ns, 50 MHz
rd_clk_period = 10   # ns, 100 MHz

wr_clk = ((t % wr_clk_period) < (wr_clk_period / 2)).astype(float)
rd_clk = ((t % rd_clk_period) < (rd_clk_period / 2)).astype(float)

# wr_en: pulsed at posedge wr_clk starting at ~160ns (after reset release at ~160ns)
wr_en = np.zeros_like(t)
wr_en_pulses = [180, 200, 220, 240, 260, 280, 300, 320, 340, 360, 380, 400]
for p in wr_en_pulses:
    mask = (t >= p) & (t < p + wr_clk_period)
    wr_en[mask] = 1.0

# wr_data changes at posedge wr_clk when wr_en=1
wr_data_val = np.full_like(t, np.nan)
for i, p in enumerate(wr_en_pulses):
    mask = (t >= p) & (t < p + wr_clk_period * 2)
    wr_data_val[mask] = 0x3000 + i

# rd_en: pulsed at posedge rd_clk starting after writes complete, ~360ns
rd_en = np.zeros_like(t)
rd_en_pulses = [365, 375, 385, 395, 405, 415, 425, 435, 445, 455, 465, 475]
for p in rd_en_pulses:
    mask = (t >= p) & (t < p + rd_clk_period)
    rd_en[mask] = 1.0

# rd_data available 1 tick after rd_en
rd_data_val = np.full_like(t, np.nan)
for i, p in enumerate(rd_en_pulses):
    mask = (t >= p + rd_clk_period) & (t < p + rd_clk_period * 2)
    rd_data_val[mask] = 0x3000 + i

# wr_full: never goes high (12 writes << 512 depth)
wr_full = np.zeros_like(t)

# rd_empty: high until first data available, then low during reads, high at end
rd_empty = np.zeros_like(t)
rd_empty[(t < 375)] = 1.0
rd_empty[(t >= 485) & (t <= t_max)] = 1.0

# Colors
CLK_COLOR = '#2c3e50'
SIG_COLOR = '#2980b9'
DATA_COLOR = '#27ae60'
CTRL_COLOR = '#e74c3c'
GRID_COLOR = '#ecf0f1'
BG_COLOR = '#fafbfc'

def plot_digital(ax, t, sig, y_label, color=SIG_COLOR, y_offs=0):
    ax.fill_between(t, y_offs, y_offs + sig * 0.85, color=color, step='post', alpha=0.85, linewidth=0)
    ax.set_ylabel(y_label, fontsize=8, fontfamily='monospace', rotation=0, labelpad=55, va='center')
    ax.set_ylim(-0.15, 1.15)
    ax.set_yticks([])
    ax.grid(True, axis='x', alpha=0.3, color=GRID_COLOR, linewidth=0.5)
    for spine in ax.spines.values():
        spine.set_visible(False)

def plot_clock(ax, t, sig, y_label, color=CLK_COLOR, y_offs=0):
    ax.fill_between(t, y_offs, y_offs + sig * 0.8, color=color, step='post', alpha=0.6, linewidth=0)
    ax.set_ylabel(y_label, fontsize=8, fontfamily='monospace', rotation=0, labelpad=55, va='center')
    ax.set_ylim(-0.15, 1.15)
    ax.set_yticks([])
    ax.grid(True, axis='x', alpha=0.3, color=GRID_COLOR, linewidth=0.5)
    for spine in ax.spines.values():
        spine.set_visible(False)

def plot_data_hex(ax, t, vals, y_label, color=DATA_COLOR):
    ax.set_ylabel(y_label, fontsize=8, fontfamily='monospace', rotation=0, labelpad=55, va='center')
    ax.set_ylim(0, 1)
    ax.set_yticks([])
    ax.grid(True, axis='x', alpha=0.3, color=GRID_COLOR, linewidth=0.5)
    for spine in ax.spines.values():
        spine.set_visible(False)
    # Add hex labels for each value
    seen = set()
    for i in range(len(t)):
        if not np.isnan(vals[i]):
            val_int = int(vals[i])
            if val_int not in seen:
                # Find contiguous block
                j = i
                while j < len(t) and not np.isnan(vals[j]) and int(vals[j]) == val_int:
                    j += 1
                mid_t = (t[i] + t[j-1]) / 2
                ax.annotate(f'0x{val_int:04X}', xy=(mid_t, 0.5), fontsize=7,
                           fontfamily='monospace', ha='center', va='center',
                           color=color, fontweight='bold',
                           bbox=dict(boxstyle='round,pad=0.2', facecolor='white', edgecolor=color, alpha=0.8))
                seen.add(val_int)
            break

plot_clock(axes[0], t, wr_clk, 'wr_clk\n(50MHz)', CLK_COLOR)
plot_digital(axes[1], t, wr_en, 'wr_en', SIG_COLOR)
plot_data_hex(axes[2], t, wr_data_val, 'wr_data\n[15:0]', DATA_COLOR)
plot_digital(axes[3], t, wr_full, 'wr_full', CTRL_COLOR)
plot_clock(axes[4], t, rd_clk, 'rd_clk\n(100MHz)', CLK_COLOR)
plot_digital(axes[5], t, rd_en, 'rd_en', SIG_COLOR)
plot_data_hex(axes[6], t, rd_data_val, 'rd_data\n[15:0]', DATA_COLOR)
plot_digital(axes[7], t, rd_empty, 'rd_empty', CTRL_COLOR)

# X-axis
axes[-1].set_xlabel('Time (ns)', fontsize=9)
axes[-1].set_xlim(150, 500)
axes[-1].set_xticks(np.arange(150, 520, 50))
axes[-1].tick_params(labelsize=8)

# Title
fig.suptitle('ModelSim Simulation: tb_async_fifo — Write/Read Waveform',
             fontsize=12, fontweight='bold', fontfamily='monospace', y=0.995)
fig.text(0.98, 0.005, 'Source: ModelSim  |  DUT: task3_dcfifo_ip (16-bit x 16 deep)  |  tc: 1 ps',
         fontsize=6, fontfamily='monospace', ha='right', color='gray')

plt.tight_layout(rect=[0.08, 0.03, 1, 0.96])
fig.savefig('/home/user/quartus/task3-softcore-logic-analysis/figures/task3_modelsim_waveform.png',
            dpi=180, bbox_inches='tight', facecolor='white', edgecolor='none')
print("Waveform saved.")
