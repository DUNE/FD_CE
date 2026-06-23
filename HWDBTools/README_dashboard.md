# HWDBTools Dashboard

This module provides a small dashboard generator for ASIC test data stored in the DUNE HWDB.

## Files

- `dashboard.py` — generates a static PNG chart and HTML report, and optionally an interactive Plotly HTML dashboard.

## Requirements

- `python3`
- `matplotlib`
- `requests`
- `plotly` (optional, only required for `--interactive` output)

## Usage

From `HWDBTools/`:

```bash
python3 dashboard.py coldadc_p2prb2 --output asic_dashboard
```

This creates:

- `asic_dashboard.png`
- `asic_dashboard.html`

To create an interactive HTML dashboard instead:

```bash
python3 dashboard.py coldadc_p2prb2 --output asic_dashboard --interactive
```

If you want to filter by site location:

```bash
python3 dashboard.py coldadc_p2prb2 --location FNAL --output asic_dashboard
```

## Notes

- The dashboard aggregates ASIC tests by the first recorded test date.
- Pass/fail values are inferred from test data entries containing `PASS` or `FAIL`, and from item status codes where available.
- If Plotly is not installed, the script still creates a static PNG + HTML dashboard.
