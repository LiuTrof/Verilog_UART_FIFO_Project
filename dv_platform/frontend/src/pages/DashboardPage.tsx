import { Activity, CircleCheckBig, CircleX, Clock3, Layers3, Play } from "lucide-react";
import { Metric } from "../components/Metric";
import { StatusBadge } from "../components/StatusBadge";
import type { Dashboard, Regression, TestCase } from "../types";

interface DashboardPageProps {
  dashboard: Dashboard;
  regressions: Regression[];
  testcases: TestCase[];
  running: boolean;
  onRunAll: () => void;
}

const formatDate = (timestamp: string | null) =>
  timestamp ? new Intl.DateTimeFormat("zh-CN", { dateStyle: "short", timeStyle: "medium" }).format(new Date(timestamp)) : "等待执行";

export function DashboardPage({ dashboard, regressions, testcases, running, onRunAll }: DashboardPageProps) {
  // The shared list updates from live regression events; the dashboard remains the persisted summary.
  const latest = regressions[0] ?? dashboard.latest_regression;
  const passedTestcases = testcases.length
    ? testcases.filter((testcase) => testcase.result === "passed").length
    : dashboard.passed_testcases;
  const failedTestcases = testcases.length
    ? testcases.filter((testcase) => testcase.result === "failed").length
    : dashboard.failed_testcases;
  const passRate = testcases.length
    ? Math.round((passedTestcases / testcases.length) * 10000) / 100
    : dashboard.pass_rate;
  const passedRuns = regressions.filter((regression) => regression.status === "passed").length;
  const failedRuns = regressions.filter((regression) => regression.status === "failed").length;
  const activeRuns = regressions.filter((regression) => regression.status === "queued").length;
  const historyInsight = !regressions.length
    ? "尚无历史任务。启动一次完整回归后，结果会保留在这里。"
    : activeRuns
      ? `当前有 ${activeRuns} 条任务正在执行，已完成的场景结果可在回归中心实时查看。`
      : failedRuns
        ? `历史中有 ${failedRuns} 条失败任务，建议优先在回归中心查看对应场景日志。`
        : `共 ${passedRuns} 条历史任务已通过，最近一次回归结果稳定。`;
  return (
    <div className="page-stack workbench-page dashboard-page">
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
        <Metric label="通过率" value={`${passRate}%`} hint={`${passedTestcases} 个用例最新结果通过`} tone="green" />
        <Metric label="失败用例" value={failedTestcases} hint="需要查看日志与波形" tone="red" />
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

      <article className="panel history-panel">
        <div className="panel-title">
          <div><p className="eyebrow">RECENT ACTIVITY</p><h2>回归历史</h2></div>
          <div className="panel-title-actions"><span className="panel-count">{regressions.length} 条记录</span><Activity size={20} /></div>
        </div>
        <div className="history-summary" aria-label="回归历史摘要">
          <div className="history-summary-item history-summary-passed">
            <span className="history-summary-icon"><CircleCheckBig size={19} /></span>
            <div className="history-summary-copy"><span>已通过</span><strong>{passedRuns}<small>条任务</small></strong></div>
          </div>
          <div className="history-summary-item history-summary-failed">
            <span className="history-summary-icon"><CircleX size={19} /></span>
            <div className="history-summary-copy"><span>需关注</span><strong>{failedRuns}<small>条任务</small></strong></div>
          </div>
          <div className="history-summary-item history-summary-running">
            <span className="history-summary-icon"><Clock3 size={19} /></span>
            <div className="history-summary-copy"><span>执行中</span><strong>{activeRuns}<small>条任务</small></strong></div>
          </div>
        </div>
        <p className="history-insight"><Activity size={15} />{historyInsight}</p>
        <div className="table-wrap history-table-scroll" tabIndex={0} aria-label="全部回归历史记录">
          <table>
            <thead><tr><th>任务</th><th>状态</th><th>场景通过</th><th>仿真器</th><th>执行时间</th></tr></thead>
            <tbody>
              {regressions.map((regression) => (
                <tr key={regression.id} data-status={regression.status}>
                  <td><div className="history-task"><strong className="mono">{regression.id}</strong><small>{regression.finished_at ? "已完成归档" : "正在记录结果"}</small></div></td>
                  <td><StatusBadge status={regression.status} /></td>
                  <td><span className="history-result">{regression.total_cases ? `${regression.passed_cases}/${regression.total_cases}` : "准备中"}<small>{regression.total_cases ? "通过场景" : "等待资源"}</small></span></td>
                  <td>{regression.simulator}</td>
                  <td><div className="history-time"><time>{formatDate(regression.started_at)}</time><small>{regression.finished_at ? `完成 ${formatDate(regression.finished_at)}` : "仍在执行"}</small></div></td>
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
