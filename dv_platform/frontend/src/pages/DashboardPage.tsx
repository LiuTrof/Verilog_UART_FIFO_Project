import { Activity, CircleCheckBig, CircleX, Layers3, Play } from "lucide-react";
import { Metric } from "../components/Metric";
import { StatusBadge } from "../components/StatusBadge";
import type { Dashboard, Regression } from "../types";

interface DashboardPageProps {
  dashboard: Dashboard;
  regressions: Regression[];
  running: boolean;
  onRunAll: () => void;
}

const formatDate = (timestamp: string | null) =>
  timestamp ? new Intl.DateTimeFormat("zh-CN", { dateStyle: "short", timeStyle: "medium" }).format(new Date(timestamp)) : "等待执行";

export function DashboardPage({ dashboard, regressions, running, onRunAll }: DashboardPageProps) {
  const latest = dashboard.latest_regression;
  return (
    <div className="page-stack">
      <section className="page-title-row">
        <div>
          <p className="eyebrow">PROJECT OVERVIEW</p>
          <h1>{dashboard.project.name}</h1>
          <p className="muted">{dashboard.project.description}</p>
        </div>
        <button className="primary-action" onClick={onRunAll} disabled={running}>
          <Play size={16} fill="currentColor" />
          {running ? "回归执行中" : "运行完整回归"}
        </button>
      </section>

      <section className="metric-grid">
        <Metric label="验证用例" value={dashboard.total_testcases} hint="验证计划内的场景" tone="cyan" />
        <Metric label="通过率" value={`${dashboard.pass_rate}%`} hint={`${dashboard.passed_testcases} 个用例最新结果通过`} tone="green" />
        <Metric label="失败用例" value={dashboard.failed_testcases} hint="需要查看日志与波形" tone="red" />
        <Metric label="最近回归" value={latest ? `${latest.passed_cases}/${latest.total_cases}` : "--"} hint={latest ? latest.simulator : "尚未执行"} tone="amber" />
      </section>

      <section className="content-grid">
        <article className="panel run-panel">
          <div className="panel-title">
            <div>
              <p className="eyebrow">REGRESSION STATUS</p>
              <h2>最近一次回归</h2>
            </div>
            {latest ? <StatusBadge status={latest.status} /> : null}
          </div>
          {latest ? (
            <dl className="run-details">
              <div><dt>任务编号</dt><dd>{latest.id}</dd></div>
              <div><dt>仿真器</dt><dd>{latest.simulator}</dd></div>
              <div><dt>开始时间</dt><dd>{formatDate(latest.started_at)}</dd></div>
              <div><dt>完成时间</dt><dd>{formatDate(latest.finished_at)}</dd></div>
            </dl>
          ) : (
            <div className="empty-state"><strong>暂无回归记录</strong><span>从右上角启动完整回归。</span></div>
          )}
        </article>

        <article className="panel coverage-panel">
          <div className="panel-title">
            <div>
              <p className="eyebrow">COVERAGE</p>
              <h2>覆盖率状态</h2>
            </div>
            <Layers3 size={20} />
          </div>
          <div className="coverage-list">
            {[
              ["Line", dashboard.coverage.line_coverage],
              ["Branch", dashboard.coverage.branch_coverage],
              ["FSM", dashboard.coverage.fsm_coverage],
              ["Functional", dashboard.coverage.functional_coverage]
            ].map(([label, value]) => (
              <div className="coverage-row" key={String(label)}>
                <span>{label}</span>
                <div className="coverage-track"><i style={{ width: typeof value === "number" ? `${value}%` : "0%" }} /></div>
                <strong>{typeof value === "number" ? `${value}%` : "未采集"}</strong>
              </div>
            ))}
          </div>
          <p className="panel-note">{dashboard.coverage.source === "not_collected" ? "Icarus 自检回归不生成覆盖率数据库。接入商业仿真器后可导入覆盖率。" : "等待回归覆盖率导入。"}</p>
        </article>
      </section>

      <article className="panel">
        <div className="panel-title">
          <div><p className="eyebrow">RECENT ACTIVITY</p><h2>回归历史</h2></div>
          <Activity size={20} />
        </div>
        <div className="table-wrap">
          <table>
            <thead><tr><th>任务</th><th>状态</th><th>结果</th><th>仿真器</th><th>开始时间</th></tr></thead>
            <tbody>
              {regressions.slice(0, 6).map((regression) => (
                <tr key={regression.id}>
                  <td className="mono">{regression.id}</td>
                  <td><StatusBadge status={regression.status} /></td>
                  <td>{regression.total_cases ? `${regression.passed_cases}/${regression.total_cases} 通过` : "准备中"}</td>
                  <td>{regression.simulator}</td>
                  <td>{formatDate(regression.started_at)}</td>
                </tr>
              ))}
              {!regressions.length && <tr><td colSpan={5} className="table-empty">没有可展示的回归记录。</td></tr>}
            </tbody>
          </table>
        </div>
      </article>
    </div>
  );
}
