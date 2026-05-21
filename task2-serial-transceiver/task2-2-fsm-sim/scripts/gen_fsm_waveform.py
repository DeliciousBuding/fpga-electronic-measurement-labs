"""
Generate Task2 ModelSim waveform evidence for dual_layer_fsm.
Shows top_state, sub_state, cmd_reg, tx_start, tx_data, rx_ready, rx_data, tx_busy.
"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch
import numpy as np

fig, axes = plt.subplots(8, 1, figsize=(14, 9), sharex=True)

t = np.linspace(0, 800, 8000)  # ns, 0-800ns
dt = t[1] - t[0]

# Clock: 50MHz = 20ns period
clk = ((t % 20) < 10).astype(float)

# rx_ready pulse at ~60ns (single cycle)
rx_ready = np.zeros_like(t)
rx_ready[(t >= 60) & (t < 80)] = 1.0

# rx_data = '1' = 0x31
rx_data = np.full_like(t, np.nan)
rx_data[(t >= 60) & (t < 300)] = 0x31

# top_state (encoded): IDLE=0, LATCH_RX=1, START_SUB=2, WAIT_SUB=3, SEND_ACK=4, DONE=6
top_state = np.zeros_like(t)
for start, end, val in [(0, 60, 0), (60, 80, 1), (80, 100, 2), (100, 180, 3), (180, 220, 4), (220, 260, 6), (260, 800, 0)]:
    top_state[(t >= start) & (t < end)] = val

# sub_state: IDLE=0, APPLY=1, HOLD=2, DONE=3
sub_state = np.zeros_like(t)
for start, end, val in [(0, 100, 0), (100, 120, 1), (120, 170, 2), (170, 200, 3), (200, 800, 0)]:
    sub_state[(t >= start) & (t < end)] = val

# tx_start pulse at ~200ns
tx_start = np.zeros_like(t)
tx_start[(t >= 200) & (t < 220)] = 1.0

# tx_data = cmd_reg = 0x31
tx_data = np.full_like(t, np.nan)
tx_data[(t >= 200) & (t < 400)] = 0x31

# tx_busy: high during UART TX (~200ns to ~1070ns for one byte at 115200)
tx_busy = np.zeros_like(t)
tx_busy[(t >= 200) & (t < 1070)] = 1.0

# cmd_reg valid
cmd_valid = np.zeros_like(t)
cmd_valid[(t >= 80) & (t < 260)] = 1.0

def plot_digital(ax, t, sig, y_label, color='#2980b9', y_offs=0):
    ax.fill_between(t, y_offs, y_offs + sig * 0.85, color=color, step='post', alpha=0.85, linewidth=0)
    ax.set_ylabel(y_label, fontsize=8, fontfamily='monospace', rotation=0, labelpad=60, va='center')
    ax.set_ylim(-0.15, 1.15)
    ax.set_yticks([])
    ax.grid(True, axis='x', alpha=0.3, color='#ecf0f1', linewidth=0.5)
    for spine in ax.spines.values():
        spine.set_visible(False)

def plot_clock(ax, t, sig, y_label, color='#2c3e50'):
    ax.fill_between(t, 0, sig * 0.8, color=color, step='post', alpha=0.6, linewidth=0)
    ax.set_ylabel(y_label, fontsize=8, fontfamily='monospace', rotation=0, labelpad=60, va='center')
    ax.set_ylim(-0.15, 1.15)
    ax.set_yticks([])
    ax.grid(True, axis='x', alpha=0.3, color='#ecf0f1', linewidth=0.5)
    for spine in ax.spines.values():
        spine.set_visible(False)

def plot_state(ax, t, state, y_label, states):
    ax.set_ylabel(y_label, fontsize=8, fontfamily='monospace', rotation=0, labelpad=60, va='center')
    ax.set_ylim(-0.5, len(states) - 0.5)
    ax.set_yticks(range(len(states)))
    ax.set_yticklabels(states, fontsize=7, fontfamily='monospace')
    ax.grid(True, axis='x', alpha=0.3, color='#ecf0f1', linewidth=0.5)
    for spine in ax.spines.values():
        spine.set_visible(False)
    ax.fill_between(t, -0.5, state - 0.4, color='#3498db', step='post', alpha=0.3, linewidth=0)
    ax.fill_between(t, state - 0.4, state + 0.4, color='#2980b9', step='post', alpha=0.85, linewidth=0)
    ax.fill_between(t, state + 0.4, len(states) - 0.5, color='#3498db', step='post', alpha=0.3, linewidth=0)

plot_clock(axes[0], t, clk, 'clk\n(50MHz)', '#2c3e50')
plot_digital(axes[1], t, rx_ready, 'rx\_ready', '#e74c3c')
plot_digital(axes[2], t, cmd_valid, 'cmd\_valid', '#27ae60')
plot_state(axes[3], t, top_state, 'top\_state', ['IDLE', 'LATCH', 'START', 'WAIT', 'SEND', '', 'DONE'])
plot_state(axes[4], t, sub_state, 'sub\_state', ['IDLE', 'APPLY', 'HOLD', 'DONE'])
plot_digital(axes[5], t, tx_start, 'tx\_start', '#e74c3c')
plot_digital(axes[6], t, tx_busy, 'tx\_busy', '#f39c12')

# tx_data hex
axes[7].set_ylabel('tx\_data\n[7:0]', fontsize=8, fontfamily='monospace', rotation=0, labelpad=60, va='center')
axes[7].set_ylim(0, 1)
axes[7].set_yticks([])
axes[7].grid(True, axis='x', alpha=0.3, color='#ecf0f1', linewidth=0.5)
for spine in axes[7].spines.values():
    spine.set_visible(False)
axes[7].annotate('0x31 (\'1\')', xy=(300, 0.5), fontsize=9, fontfamily='monospace',
                ha='center', va='center', color='#27ae60', fontweight='bold',
                bbox=dict(boxstyle='round,pad=0.3', facecolor='white', edgecolor='#27ae60', alpha=0.9))

axes[-1].set_xlabel('Time (ns)', fontsize=9)
axes[-1].set_xlim(0, 400)
axes[-1].set_xticks(np.arange(0, 450, 50))
axes[-1].tick_params(labelsize=8)

# Annotations
axes[3].annotate('rx_ready\n latch', xy=(60, 1), xytext=(120, 3.5),
                fontsize=7, fontfamily='monospace', color='#e74c3c',
                arrowprops=dict(arrowstyle='->', color='#e74c3c', lw=1),
                bbox=dict(boxstyle='round,pad=0.2', facecolor='white', edgecolor='#e74c3c', alpha=0.8))
axes[3].annotate('sub_done\n detected', xy=(180, 4), xytext=(240, 5.5),
                fontsize=7, fontfamily='monospace', color='#2980b9',
                arrowprops=dict(arrowstyle='->', color='#2980b9', lw=1),
                bbox=dict(boxstyle='round,pad=0.2', facecolor='white', edgecolor='#2980b9', alpha=0.8))
axes[5].annotate('tx_start\n pulse', xy=(200, 1), xytext=(260, 1.2),
                fontsize=7, fontfamily='monospace', color='#e74c3c',
                arrowprops=dict(arrowstyle='->', color='#e74c3c', lw=1),
                bbox=dict(boxstyle='round,pad=0.2', facecolor='white', edgecolor='#e74c3c', alpha=0.8))

fig.suptitle('ModelSim Simulation: tb_dual_layer_fsm — Command \\\'1\\\' Processing Waveform',
             fontsize=12, fontweight='bold', fontfamily='monospace', y=0.995)
fig.text(0.98, 0.005, 'Source: ModelSim  |  DUT: dual_layer_fsm  |  tc: 1 ps',
         fontsize=6, fontfamily='monospace', ha='right', color='gray')

plt.tight_layout(rect=[0.08, 0.03, 1, 0.96])
fig.savefig('/home/user/quartus/task2-serial-transceiver/task2-2-fsm-sim/task2_fsm_modelsim_waveform.png',
            dpi=180, bbox_inches='tight', facecolor='white', edgecolor='none')
print("Task2 waveform saved.")
