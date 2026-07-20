import { CheckCircle2, Play, Search, XCircle } from "lucide-react";
import { EmptyState } from "../components/EmptyState";
import { StatusBadge } from "../components/StatusBadge";
import type { TestCase, TestResult } from "../types";

interface TestCasesPageProps {
  cases: TestCase[];
  running: boolean;
  selected: Set<string>;
  search: string;
  resultFilter: "all" | TestResult;
  onToggle: (name: string) => void;
  onSetVisibleSelection: (names: string[], selected: boolean) => void;
  onSearch: (query: string) => void;
  onResultFilter: (result: "all" | TestResult) => void;
  onRunSelected: () => void;
}

export function TestCasesPage({ cases, selected, search, resultFilter, running, onToggle, onSetVisibleSelection, onSearch, onResultFilter, onRunSelected }: TestCasesPageProps) {
  const query = search.trim().toLocaleLowerCase();
  const visibleCases = cases.filter((testcase) => {
    const matchesSearch = !query || [testcase.name, testcase.owner, testcase.description]
      .some((value) => value.toLocaleLowerCase().includes(query));
    return matchesSearch && (resultFilter === "all" || testcase.result === resultFilter);
  });
  const allVisibleSelected = visibleCases.length > 0 && visibleCases.every((testcase) => selected.has(testcase.name));

  return (
    <div className="page-stack">
      <section className="page-title-row">
        <div><p className="eyebrow">TEST MANAGEMENT</p><h1>验证用例</h1><p className="muted">测试目的、预期检查和最近一次执行结果均来自平台数据库。</p></div>
        <button className="primary-action" onClick={onRunSelected} disabled={!selected.size || running}><Play size={16} fill="currentColor" />运行选中用例</button>
      </section>
      <section className="toolbar" aria-label="测试用例筛选">
        <label className="search-field"><Search size={16} /><input value={search} onChange={(event) => onSearch(event.target.value)} placeholder="搜索 testcase、负责人或描述" /></label>
        <select className="secondary-action testcase-filter" value={resultFilter} onChange={(event) => onResultFilter(event.target.value as "all" | TestResult)} aria-label="按最近结果筛选">
          <option value="all">所有状态</option>
          <option value="not_run">未执行</option>
          <option value="passed">通过</option>
          <option value="failed">失败</option>
        </select>
        <span className="selection-count">已选择 {selected.size} / {cases.length}</span>
      </section>
      <article className="panel testcase-panel">
        <div className="panel-title">
          <div><p className="eyebrow">TEST PLAN</p><h2>验证用例清单</h2></div>
          <div className="panel-title-actions"><span className="panel-count">{visibleCases.length} / {cases.length} 个</span></div>
        </div>
        <div className="table-wrap">
          <table className="testcase-table">
            <thead><tr><th><input type="checkbox" aria-label="选择当前筛选的全部测试用例" checked={allVisibleSelected} onChange={(event) => onSetVisibleSelection(visibleCases.map((testcase) => testcase.name), event.target.checked)} /></th><th>Testcase</th><th>测试目的</th><th>负责人</th><th>预期检查</th><th>最近结果</th></tr></thead>
            <tbody>
              {visibleCases.map((testcase) => (
                <tr key={testcase.id}>
                  <td><input type="checkbox" aria-label={`选择 ${testcase.name}`} checked={selected.has(testcase.name)} onChange={() => onToggle(testcase.name)} /></td>
                  <td><strong className="mono">{testcase.name}</strong></td>
                  <td>{testcase.description}</td>
                  <td>{testcase.owner}</td>
                  <td>{testcase.expected_checks ? `${testcase.expected_checks} 字节` : "状态边界"}</td>
                  <td><StatusBadge status={testcase.result} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!visibleCases.length && <EmptyState title={cases.length ? "没有符合条件的测试用例" : "没有测试用例"} detail={cases.length ? "调整搜索词或结果筛选后重试。" : "在项目中创建 testcase 后会出现在这里。"} />}
      </article>
      <section className="legend-row">
        <span><CheckCircle2 size={15} />通过表示 Scoreboard 零错误且无未匹配预期数据。</span>
        <span><XCircle size={15} />失败可在回归中心查看错误原因与原始日志路径。</span>
      </section>
    </div>
  );
}
