//! Menu workflow: shows the pipeline report of the server service in a popup.

/// Offers the workflow in the navigation menu.
fn show() -> Bool {
    ret true;
}

fn main() {
    let report = exo::rpc_env("crm_pipeline_report")?[0];
    let lines = [];
    for row in report.stages {
        lines.push(f"{row.stage}: {row.count} deals, {row.total}");
    }
    lines.push("");
    lines.push(f"Open pipeline: {report.open_pipeline} ({report.open_deals} deals)");
    lines.push(f"Weighted forecast: {report.weighted_forecast}");
    lines.push(f"Won revenue: {report.won_revenue}");
    if report.win_rate_percent != None {
        lines.push(f"Win rate: {report.win_rate_percent.round()} %");
    }
    ret exo::ui::popup("Sales pipeline", lines.join("\n")?);
}
