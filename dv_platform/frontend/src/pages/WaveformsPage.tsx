import { FileSearch, Search, Signal, Upload } from "lucide-react";
import type { ChangeEvent } from "react";
import { EmptyState } from "../components/EmptyState";
import type { WaveformDetails, WaveformSummary } from "../types";

interface WaveformsPageProps {
  waveforms: WaveformSummary[];
  selected: WaveformDetails | null;
  search: string;
  onSearch: (search: string) => void;
  onSelect: (name: string) => void;
  importing: boolean;
  onUpload: (file: File) => void;
}

const byteSize = (bytes: number) => bytes > 1024 * 1024 ? `${(bytes / 1024 / 1024).toFixed(1)} MB` : `${Math.max(1, Math.round(bytes / 1024))} KB`;

export function WaveformsPage({ waveforms, selected, search, onSearch, onSelect, importing, onUpload }: WaveformsPageProps) {
  const chooseVcd = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.item(0);
    if (file) onUpload(file);
    event.target.value = "";
  };

  return (
    <div className="page-stack">
      <section className="page-title-row">
        <div><p className="eyebrow">WAVEFORM ANALYSIS</p><h1>波形分析</h1><p className="muted">索引由 VCD 声明自动生成，用于快速定位 UART、FIFO 与 testbench 信号。</p></div>
        <label className={`secondary-action file-action${importing ? " disabled" : ""}`} title="导入 VCD 并建立信号索引">
          <Upload size={16} />{importing ? "导入中" : "导入 VCD"}
          <input type="file" accept=".vcd" onChange={chooseVcd} disabled={importing} />
        </label>
      </section>
      <section className="waveform-layout">
        <article className="panel waveform-files">
          <div className="panel-title"><div><p className="eyebrow">VCD FILES</p><h2>可用波形</h2></div><Signal size={20} /></div>
          <div className="wave-list">
            {waveforms.map((waveform) => <button key={waveform.name} className={`wave-list-item ${selected?.name === waveform.name ? "selected" : ""}`} onClick={() => onSelect(waveform.name)}><strong>{waveform.name}</strong><span>{byteSize(waveform.size_bytes)} · {waveform.signal_count} 个信号</span><small>{new Date(waveform.modified_at).toLocaleString("zh-CN")}</small></button>)}
            {!waveforms.length && <EmptyState title="没有 VCD 文件" detail="运行带 --wave 的单场景仿真，或通过 API 上传 VCD。" />}
          </div>
        </article>
        <article className="panel waveform-inspector">
          <div className="panel-title"><div><p className="eyebrow">SIGNAL INDEX</p><h2>{selected?.name ?? "选择 VCD"}</h2></div><FileSearch size={20} /></div>
          {selected ? <><label className="search-field"><Search size={16} /><input value={search} onChange={(event) => onSearch(event.target.value)} placeholder="按信号名称过滤，例如 tx、fifo、reset" /></label><div className="signal-summary">匹配 {selected.matched_signals.length} / {selected.signal_count} 个信号</div><div className="signal-table"><div className="signal-header"><span>层级信号</span><span>宽度</span><span>ID</span></div>{selected.matched_signals.map((signal) => <div className="signal-item" key={`${signal.identifier}-${signal.name}`}><code>{signal.name}</code><span>{signal.width}</span><code>{signal.identifier}</code></div>)}</div><details><summary>查看 VCD 文件头</summary><pre>{selected.preview}</pre></details></> : <EmptyState title="暂无选择" detail="从左侧选择 VCD 以建立信号索引。" />}
        </article>
      </section>
    </div>
  );
}
