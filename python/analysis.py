import os
import sys
import pandas as pd
import matplotlib
matplotlib.use("Agg")  # safe for headless WSL / no display
import matplotlib.pyplot as plt

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NS3_RESULTS_CSV = os.path.normpath(
    os.path.join(SCRIPT_DIR, "..", "ns-3-dev", "results_summary.csv")
)
OUTPUT_DIR = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "results"))
os.makedirs(OUTPUT_DIR, exist_ok=True)


def load_data(csv_path: str) -> pd.DataFrame:
    if not os.path.exists(csv_path):
        sys.exit(
            f"ERROR: could not find '{csv_path}'.\n"
            "Run the ns-3 simulation first:\n"
            "  cd ~/5G-Edge-Computing-Smart-City/ns-3-dev\n"
            "  ./ns3 run scratch/mec_arvr_final\n"
            "This produces 'results_summary.csv' in that folder."
        )
    df = pd.read_csv(csv_path)
    df = df[df["path"].isin(["MEC", "CLOUD"])].copy()
    if df.empty:
        sys.exit("ERROR: no MEC or CLOUD flows found in the CSV. Check the simulation output.")
    return df


def aggregate_by_path(df: pd.DataFrame) -> pd.DataFrame:
    """
    There is one flow per path in this simulation (UE->MEC, UE->Cloud),
    but we aggregate with groupby anyway so the script also works if you
    later add multiple UEs / multiple flows per path.
    """
    agg = df.groupby("path").agg(
        avg_delay_ms=("avg_delay_ms", "mean"),
        throughput_mbps=("throughput_mbps", "mean"),
        packet_loss_percent=("packet_loss_percent", "mean"),
        tx_packets=("tx_packets", "sum"),
        rx_packets=("rx_packets", "sum"),
        lost_packets=("lost_packets", "sum"),
    ).reindex(["MEC", "CLOUD"])  # force consistent ordering
    return agg


def compute_improvement(agg: pd.DataFrame) -> dict:
    mec_delay = agg.loc["MEC", "avg_delay_ms"]
    cloud_delay = agg.loc["CLOUD", "avg_delay_ms"]

    mec_tput = agg.loc["MEC", "throughput_mbps"]
    cloud_tput = agg.loc["CLOUD", "throughput_mbps"]

    latency_reduction_ms = cloud_delay - mec_delay
    latency_reduction_pct = (
        (latency_reduction_ms / cloud_delay) * 100.0 if cloud_delay > 0 else 0.0
    )
    throughput_gain_pct = (
        ((mec_tput - cloud_tput) / cloud_tput) * 100.0 if cloud_tput > 0 else 0.0
    )

    return {
        "mec_delay_ms": mec_delay,
        "cloud_delay_ms": cloud_delay,
        "latency_reduction_ms": latency_reduction_ms,
        "latency_reduction_pct": latency_reduction_pct,
        "mec_throughput_mbps": mec_tput,
        "cloud_throughput_mbps": cloud_tput,
        "throughput_gain_pct": throughput_gain_pct,
        "mec_loss_pct": agg.loc["MEC", "packet_loss_percent"],
        "cloud_loss_pct": agg.loc["CLOUD", "packet_loss_percent"],
    }


# ---------------------------------------------------------------------------
# Plots
# ---------------------------------------------------------------------------
COLORS = {"MEC": "#2E86AB", "CLOUD": "#E94F37"}


def plot_latency(agg: pd.DataFrame, outpath: str):
    fig, ax = plt.subplots(figsize=(6, 5))
    paths = agg.index.tolist()
    values = agg["avg_delay_ms"].values
    bars = ax.bar(paths, values, color=[COLORS[p] for p in paths], width=0.5)
    ax.set_ylabel("Average End-to-End Delay (ms)")
    ax.set_title("Latency Comparison: MEC vs Cloud")
    ax.bar_label(bars, fmt="%.2f ms", padding=3)
    ax.set_ylim(0, max(values) * 1.3 if max(values) > 0 else 1)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    fig.tight_layout()
    fig.savefig(outpath, dpi=150)
    plt.close(fig)


def plot_throughput(agg: pd.DataFrame, outpath: str):
    fig, ax = plt.subplots(figsize=(6, 5))
    paths = agg.index.tolist()
    values = agg["throughput_mbps"].values
    bars = ax.bar(paths, values, color=[COLORS[p] for p in paths], width=0.5)
    ax.set_ylabel("Throughput (Mbps)")
    ax.set_title("Throughput Comparison: MEC vs Cloud")
    ax.bar_label(bars, fmt="%.2f Mbps", padding=3)
    ax.set_ylim(0, max(values) * 1.3 if max(values) > 0 else 1)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    fig.tight_layout()
    fig.savefig(outpath, dpi=150)
    plt.close(fig)


def plot_packet_loss(agg: pd.DataFrame, outpath: str):
    fig, ax = plt.subplots(figsize=(6, 5))
    paths = agg.index.tolist()
    values = agg["packet_loss_percent"].values
    bars = ax.bar(paths, values, color=[COLORS[p] for p in paths], width=0.5)
    ax.set_ylabel("Packet Loss (%)")
    ax.set_title("Packet Loss Comparison: MEC vs Cloud")
    ax.bar_label(bars, fmt="%.2f%%", padding=3)
    ax.set_ylim(0, max(values) * 1.3 + 0.5 if max(values) >= 0 else 1)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    fig.tight_layout()
    fig.savefig(outpath, dpi=150)
    plt.close(fig)


def plot_combined(agg: pd.DataFrame, outpath: str):
    """A single combined figure: latency, throughput, packet loss, and a
    pie chart of relative latency share — useful as the one figure for
    slides/report front page."""
    fig, axes = plt.subplots(2, 2, figsize=(11, 9))
    paths = agg.index.tolist()
    colors = [COLORS[p] for p in paths]

    # Latency
    ax = axes[0, 0]
    bars = ax.bar(paths, agg["avg_delay_ms"], color=colors, width=0.5)
    ax.set_title("Average Delay (ms)")
    ax.bar_label(bars, fmt="%.2f")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    # Throughput
    ax = axes[0, 1]
    bars = ax.bar(paths, agg["throughput_mbps"], color=colors, width=0.5)
    ax.set_title("Throughput (Mbps)")
    ax.bar_label(bars, fmt="%.2f")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    # Packet loss
    ax = axes[1, 0]
    bars = ax.bar(paths, agg["packet_loss_percent"], color=colors, width=0.5)
    ax.set_title("Packet Loss (%)")
    ax.bar_label(bars, fmt="%.2f")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    # Pie: share of total delay contributed by each path (illustrative)
    ax = axes[1, 1]
    delay_values = agg["avg_delay_ms"].clip(lower=0.0001)  # avoid zero-slice issues
    ax.pie(
        delay_values,
        labels=paths,
        colors=colors,
        autopct="%.1f%%",
        startangle=90,
    )
    ax.set_title("Relative Share of End-to-End Delay")

    fig.suptitle("5G MEC vs Cloud — AR/VR Performance Summary", fontsize=14, fontweight="bold")
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    fig.savefig(outpath, dpi=150)
    plt.close(fig)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    df = load_data(NS3_RESULTS_CSV)
    agg = aggregate_by_path(df)
    improvement = compute_improvement(agg)

    # Plots
    plot_latency(agg, os.path.join(OUTPUT_DIR, "latency.png"))
    plot_throughput(agg, os.path.join(OUTPUT_DIR, "throughput.png"))
    plot_packet_loss(agg, os.path.join(OUTPUT_DIR, "packet_loss.png"))
    plot_combined(agg, os.path.join(OUTPUT_DIR, "comparison.png"))

    # Comparison table CSV (clean version for the report / MATLAB import)
    table = agg.reset_index().rename(columns={"path": "Path"})
    table.to_csv(os.path.join(OUTPUT_DIR, "comparison_table.csv"), index=False)

    # Also copy a MATLAB-friendly raw CSV (same data, explicit column order)
    df.to_csv(os.path.join(OUTPUT_DIR, "latency.csv"), index=False)
    df.to_csv(os.path.join(OUTPUT_DIR, "throughput.csv"), index=False)

    # Plain text summary
    summary_path = os.path.join(OUTPUT_DIR, "summary.txt")
    with open(summary_path, "w") as f:
        f.write("5G MEC vs Cloud — AR/VR Performance Summary\n")
        f.write("=" * 50 + "\n\n")
        f.write(f"MEC average delay   : {improvement['mec_delay_ms']:.3f} ms\n")
        f.write(f"Cloud average delay : {improvement['cloud_delay_ms']:.3f} ms\n")
        f.write(
            f"Latency reduction   : {improvement['latency_reduction_ms']:.3f} ms "
            f"({improvement['latency_reduction_pct']:.2f}% lower with MEC)\n\n"
        )
        f.write(f"MEC throughput      : {improvement['mec_throughput_mbps']:.3f} Mbps\n")
        f.write(f"Cloud throughput    : {improvement['cloud_throughput_mbps']:.3f} Mbps\n")
        f.write(f"Throughput gain     : {improvement['throughput_gain_pct']:.2f}% with MEC\n\n")
        f.write(f"MEC packet loss     : {improvement['mec_loss_pct']:.3f}%\n")
        f.write(f"Cloud packet loss   : {improvement['cloud_loss_pct']:.3f}%\n")

    # Console output
    print("\n=== Analysis complete ===")
    print(f"Read: {NS3_RESULTS_CSV}")
    print(f"Wrote outputs to: {OUTPUT_DIR}/")
    print("  latency.png, throughput.png, packet_loss.png, comparison.png")
    print("  comparison_table.csv, latency.csv, throughput.csv, summary.txt\n")
    with open(summary_path) as f:
        print(f.read())


if __name__ == "__main__":
    main()
