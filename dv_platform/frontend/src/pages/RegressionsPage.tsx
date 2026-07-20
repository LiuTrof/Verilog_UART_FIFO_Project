import { CheckCircle2, Clock3, FileText, Play, RefreshCw } from "lucide-react";
import { EmptyState } from "../components/EmptyState";
import { StatusBadge } from "../components/StatusBadge";
import type { Regression, Simulation } from "../types";

interface RegressionsPageProps {
  regressions: Regression[];
  selectedRegression: Regression | null;
  simulations: Simulation[];
  running: boolean;
  onRunAll: () => void;
  onSelect: (regression: Regression) => void;
  onRefresh: () => void;
}

const dateTime = (value: string) => new Intl.DateTimeFormat("zh-CN", { dateStyle: "short", timeStyle: "medium" }).format(new Date(value));
const testcaseName = (simulation: Simulation) => simulation.testcase_name ?? simulation.log_path.split("_").pop()?.replace(".log", "") ?? "case";

export function RegressionsPage({ regressions, selectedRegression, simulations, running, onRunAll, onSelect, onRefresh }: RegressionsPageProps) {
  return (
    <div className="page-stack">
      <section className="page-title-row">
        <div><p className="eyebrow">REGRESSION CENTER</p><h1>回归任务</h1><p className="muted">每个任务保留编译结果、场景状态、运行时间和完整日志路径。</p></div>
        <div className="button-row"><button className="icon-button" onClick={onRefresh} title="刷新回归状态"><RefreshCw size={17} /></button><button className="primary-action" onClick={onRunAll} disabled={running}><Play size={16} fill="currentColor" />{running ? "执行中" : "发起完整回归"}</button></div>
      </section>
      <section className="regression-layout">
        <article className="panel run-list">
          <div className="panel-title"><div><p className="eyebrow">RUNS</p><h2>任务队列</h2></div><Clock3 size={20} /></div>
          <div className="run-list-body">
            {regressions.map((regression) => (
              <button key={regression.id} className={`run-list-item ${selectedRegression?.id === regression.id ? "selected" : ""}`} onClick={() => onSelect(regression)}>
                <span className="run-list-top"><strong className="mono">{regression.id}</strong><StatusBadge status={regression.status} /></span>
                <span>{regression.total_cases ? `${regression.passed_cases}/${regression.total_cases} 通过` : "等待仿真资源"}</span>
                <small>{dateTime(regression.started_at)}</small>
              </button>
            ))}
            {!regressions.length && <EmptyState title="暂无回归任务" detail="启动完整回归后，任务状态会实时写入此处。" />}
          </div>
        </article>
        <article className="panel details-panel">
          <div className="panel-title"><div><p className="eyebrow">RUN DETAILS</p><h2>{selectedRegression?.id ?? "选择一个任务"}</h2></div>{selectedRegression && <StatusBadge status={selectedRegression.status} />}</div>
          {selectedRegression ? <>
            <dl className="run-details compact"><div><dt>仿真器</dt><dd>{selectedRegression.simulator}</dd></div><div><dt>完成情况</dt><dd>{selectedRegression.total_cases ? `${selectedRegression.passed_cases}/${selectedRegression.total_cases} 已通过，${simulations.length}/${selectedRegression.total_cases} 已完成` : "准备中"}</dd></div><div><dt>报告路径</dt><dd className="path-text">{selectedRegression.report_path ?? "全部场景完成后生成"}</dd></div></dl>
            <section className="live-results" aria-live="polite">
              <div className="live-results-title"><div><p className="eyebrow">CASE RESULTS</p><h3>场景执行结果</h3></div><span>{simulations.length}/{selectedRegression.total_cases || "-"} 已完成</span></div>
              <div className="simulation-list">
                {simulations.map((simulation) => <section className={`simulation-row simulation-${simulation.status}`} key={simulation.id}><div><strong className="mono">{testcaseName(simulation)}</strong><span>{simulation.status === "passed" ? "场景执行成功" : "场景执行失败"}，{simulation.checked_bytes ?? 0} 字节检查，{simulation.runtime_seconds.toFixed(3)} 秒</span></div><div><StatusBadge status={simulation.status} /><small>{simulation.failure_reason ?? simulation.log_path}</small></div></section>)}
                {!simulations.length && <EmptyState title={selectedRegression.status === "queued" ? "正在等待第一个场景结果" : "没有场景结果"} detail={selectedRegression.status === "queued" ? "每个测试场景完成后会立即显示在这里。" : "请查看报告路径或任务日志。"} />}
              </div>
              {simulations.length > 0 && <div className="live-summary"><CheckCircle2 size={16} />已完成的场景会在执行过程中立即写入并保留在此处。</div>}
            </section>
          </> : <div className="empty-state"><FileText size={24} /><strong>选择回归任务</strong><span>查看每个场景的结果、耗时和日志位置。</span></div>}
        </article>
      </section>
    </div>
  );
}
