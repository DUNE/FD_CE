#!/usr/bin/env python3
"""Generate a graphical dashboard for ASIC tests from the DUNE HWDB."""

import argparse
import datetime
from collections import defaultdict

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

import dune_ce_hwdb

try:
    import plotly.graph_objects as go
    import plotly.io as pio
    PLOTLY_AVAILABLE = True
except ImportError:
    PLOTLY_AVAILABLE = False


def parse_datetime(date_str, time_str=None):
    if date_str is None:
        return None

    candidate = date_str.strip()
    if time_str is not None and len(time_str.strip()) > 0:
        candidate = f"{candidate} {time_str.strip()}"

    for fmt in [
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d %H:%M",
        "%Y-%m-%d",
        "%m/%d/%Y %H:%M:%S",
        "%m/%d/%Y %H:%M",
        "%m/%d/%Y",
    ]:
        try:
            return datetime.datetime.strptime(candidate, fmt)
        except ValueError:
            continue

    return None


def build_test_record(test_id, test_type, fields, values):
    record = {
        "id": test_id,
        "type": test_type,
        "test_data": {},
    }

    if fields is not None and values is not None:
        record["test_data"] = {field: value for field, value in zip(fields, values)}

    return record


def infer_test_result(test_data):
    if not test_data:
        return None

    raw_values = [str(v).upper() for v in test_data.values() if v is not None]
    if any("FAIL" in value for value in raw_values):
        return False
    if any("PASS" in value for value in raw_values):
        return True
    return None


def infer_item_pass_status(item_id, test_records):
    try:
        status_name, status_id, certified_qaqc, is_installed, qc_uploaded = dune_ce_hwdb.GetItemStatus(item_id)
    except Exception:
        status_name = status_id = certified_qaqc = None

    if status_id == 120 or certified_qaqc:
        return True
    if status_id == 130:
        return False

    for record in test_records:
        result = infer_test_result(record["test_data"])
        if result is False:
            return False
    for record in test_records:
        result = infer_test_result(record["test_data"])
        if result is True:
            return True

    return None


def get_test_records(item_id):
    testsIDsList, testsTypesList, testsFieldsList, testsValuesList, testsImagesList = dune_ce_hwdb.GetItemTests(item_id)
    records = []
    if testsIDsList is None:
        return records

    for i in range(len(testsIDsList)):
        records.append(
            build_test_record(
                testsIDsList[i],
                testsTypesList[i],
                testsFieldsList[i],
                testsValuesList[i],
            )
        )

    return records


def get_first_test_datetime(test_records):
    datetimes = []
    for record in test_records:
        data = record["test_data"]
        if not data:
            continue

        date_str = data.get("Test Date") or data.get("Date")
        time_str = data.get("Test Time") or data.get("Time")
        dt = parse_datetime(date_str, time_str)
        if dt is not None:
            datetimes.append(dt)

    return min(datetimes) if datetimes else None


def aggregate_dashboard_data(part_name, location=None):
    item_ids = dune_ce_hwdb.GetPartList(part_name)
    daily_counts = defaultdict(lambda: {"tested": 0, "passed": 0, "unknown": 0})

    for item_id in item_ids:
        if location is not None:
            current_location = dune_ce_hwdb.GetCurrentLocation(item_id)
            if current_location is None or current_location[1] != location:
                continue

        test_records = get_test_records(item_id)
        if not test_records:
            continue

        first_test_dt = get_first_test_datetime(test_records)
        if first_test_dt is None:
            continue

        day = first_test_dt.date()
        pass_status = infer_item_pass_status(item_id, test_records)

        daily_counts[day]["tested"] += 1
        if pass_status is True:
            daily_counts[day]["passed"] += 1
        elif pass_status is None:
            daily_counts[day]["unknown"] += 1

    return daily_counts


def create_plot(daily_counts, output_png, part_name):
    if not daily_counts:
        raise ValueError("No test data was found for the selected part name.")

    sorted_days = sorted(daily_counts)
    tested = [daily_counts[day]["tested"] for day in sorted_days]
    passed = [daily_counts[day]["passed"] for day in sorted_days]
    pass_rates = [100.0 * passed[i] / tested[i] if tested[i] > 0 else 0.0 for i in range(len(sorted_days))]

    fig, ax1 = plt.subplots(figsize=(12, 6))
    ax1.bar(sorted_days, tested, width=0.8, alpha=0.6, label="ASICs Tested", color="#1976D2")
    ax1.set_xlabel("Date")
    ax1.set_ylabel("ASICs Tested", color="#1976D2")
    ax1.tick_params(axis="y", labelcolor="#1976D2")
    ax1.set_title(f"ASIC Test Dashboard: {part_name}")

    ax2 = ax1.twinx()
    ax2.plot(sorted_days, pass_rates, marker="o", color="#C2185B", label="Pass Rate")
    ax2.set_ylabel("Pass Rate (%)", color="#C2185B")
    ax2.tick_params(axis="y", labelcolor="#C2185B")
    ax2.set_ylim(0, 100)

    fig.tight_layout()
    fig.autofmt_xdate(rotation=45)
    fig.legend(loc="upper left", bbox_to_anchor=(0.12, 0.92))
    fig.savefig(output_png, dpi=150)
    plt.close(fig)


def save_html(output_html, output_png, daily_counts, part_name, location=None):
    total_tested = sum(data["tested"] for data in daily_counts.values())
    total_passed = sum(data["passed"] for data in daily_counts.values())
    overall_rate = 100.0 * total_passed / total_tested if total_tested else 0.0

    location_text = f" for location {location}" if location else ""
    html = f"""
<html>
<head>
    <meta charset="utf-8" />
    <title>ASIC Test Dashboard - {part_name}</title>
</head>
<body>
    <h1>ASIC Test Dashboard</h1>
    <p>Part: <strong>{part_name}</strong>{location_text}</p>
    <p>Total ASICs tested: <strong>{total_tested}</strong></p>
    <p>Total passed: <strong>{total_passed}</strong></p>
    <p>Overall pass rate: <strong>{overall_rate:.1f}%</strong></p>
    <img src="{output_png}" alt="ASIC Test Dashboard" style="max-width:100%;height:auto;" />
</body>
</html>
"""

    with open(output_html, "w", encoding="utf-8") as f:
        f.write(html)


def create_interactive_html(output_html, daily_counts, part_name, location=None):
    if not PLOTLY_AVAILABLE:
        raise RuntimeError("Plotly is required for interactive dashboard generation. Install it with 'pip install plotly'.")

    sorted_days = sorted(daily_counts)
    tested = [daily_counts[day]["tested"] for day in sorted_days]
    passed = [daily_counts[day]["passed"] for day in sorted_days]
    pass_rates = [100.0 * passed[i] / tested[i] if tested[i] > 0 else 0.0 for i in range(len(sorted_days))]

    fig = go.Figure()
    fig.add_trace(go.Bar(
        x=sorted_days,
        y=tested,
        name="ASICs Tested",
        marker_color="#1976D2",
        opacity=0.75,
    ))
    fig.add_trace(go.Scatter(
        x=sorted_days,
        y=pass_rates,
        name="Pass Rate (%)",
        mode="lines+markers",
        marker=dict(color="#C2185B"),
        yaxis="y2",
    ))

    fig.update_layout(
        title=f"ASIC Test Dashboard: {part_name}",
        xaxis_title="Date",
        yaxis_title="ASICs Tested",
        yaxis2=dict(
            title="Pass Rate (%)",
            overlaying="y",
            side="right",
            range=[0, 100],
        ),
        legend=dict(x=0.02, y=0.98),
        margin=dict(l=70, r=70, t=80, b=70),
    )

    total_tested = sum(data["tested"] for data in daily_counts.values())
    total_passed = sum(data["passed"] for data in daily_counts.values())
    overall_rate = 100.0 * total_passed / total_tested if total_tested else 0.0
    location_text = f" for location {location}" if location else ""

    summary_html = f"""
<div style=\"font-family:Arial,Helvetica,sans-serif; margin-bottom:20px;\">
  <h1>ASIC Test Dashboard</h1>
  <p>Part: <strong>{part_name}</strong>{location_text}</p>
  <p>Total ASICs tested: <strong>{total_tested}</strong></p>
  <p>Total passed: <strong>{total_passed}</strong></p>
  <p>Overall pass rate: <strong>{overall_rate:.1f}%</strong></p>
</div>
"""

    plot_html = pio.to_html(fig, full_html=False, include_plotlyjs="cdn")
    html = f"""
<html>
<head>
    <meta charset=\"utf-8\" />
    <title>ASIC Test Dashboard - {part_name}</title>
</head>
<body>
    {summary_html}
    {plot_html}
</body>
</html>
"""

    with open(output_html, "w", encoding="utf-8") as f:
        f.write(html)


def main():
    parser = argparse.ArgumentParser(description="Create an ASIC test dashboard from the DUNE HWDB.")
    parser.add_argument("part_name", help="Component part name, e.g. coldadc_p2prb2")
    parser.add_argument("--location", help="Optional site location filter, e.g. FNAL")
    parser.add_argument("--output", default="hwdb_dashboard", help="Output base name for PNG and HTML files")
    parser.add_argument("--interactive", action="store_true", help="Generate an interactive HTML dashboard using Plotly.")
    args = parser.parse_args()

    daily_counts = aggregate_dashboard_data(args.part_name, args.location)
    output_png = f"{args.output}.png"
    output_html = f"{args.output}.html"
    create_plot(daily_counts, output_png, args.part_name)

    if args.interactive:
        create_interactive_html(output_html, daily_counts, args.part_name, args.location)
        print(f"Interactive dashboard generated: {output_html}")
    else:
        save_html(output_html, output_png, daily_counts, args.part_name, args.location)
        print(f"Dashboard generated: {output_html}")

    print(f"Chart image written: {output_png}")


if __name__ == "__main__":
    main()
