import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Activity, ChartNoAxesCombined, ChevronRight, FileChartColumn, LayoutDashboard, Menu, PanelLeftClose, PanelLeftOpen, TestTube2, X } from "lucide-react";
import { platformApi } from "./api";
import { LoadingState } from "./components/LoadingState";
import { DashboardPage } from "./pages/DashboardPage";
import { RegressionsPage } from "./pages/RegressionsPage";
import { TestCasesPage } from "./pages/TestCasesPage";
import { WaveformsPage } from "./pages/WaveformsPage";
import type { Dashboard, Project, Regression, Simulation, TestCase, TestResult, WaveformDetails, WaveformSummary } from "./types";

type View = "dashboard" | "testcases" | "regressions" | "waveforms";

interface NavigationItem {
  view: View;
  label: string;
  icon: typeof LayoutDashboard;
}

const MOBILE_SIDEBAR_BREAKPOINT = 620;
const navigation: NavigationItem[] = [
  { view: "dashboard", label: "仪表盘", icon: LayoutDashboard },
  { view: "testcases", label: "测试管理", icon: TestTube2 },
  { view: "regressions", label: "回归中心", icon: Activity },
  { view: "waveforms", label: "波形分析", icon: FileChartColumn }
];

const apiErrorMessage = (reason: unknown, fallback: string) =>
  reason instanceof Error ? reason.message : fallback;

export function App() {
  const [view, setView] = useState<View>("dashboard");
  const [project, setProject] = useState<Project | null>(null);
  const [dashboard, setDashboard] = useState<Dashboard | null>(null);
  const [testcases, setTestcases] = useState<TestCase[]>([]);
  const [testcasesLoaded, setTestcasesLoaded] = useState(false);
  const [regressions, setRegressions] = useState<Regression[]>([]);
  const [selectedRegression, setSelectedRegression] = useState<Regression | null>(null);
  const [simulations, setSimulations] = useState<Simulation[]>([]);
  const [waveforms, setWaveforms] = useState<WaveformSummary[]>([]);
  const [waveformsLoaded, setWaveformsLoaded] = useState(false);
  const [selectedWaveform, setSelectedWaveform] = useState<WaveformDetails | null>(null);
  const [waveformSearch, setWaveformSearch] = useState("");
  const [importingWaveform, setImportingWaveform] = useState(false);
  const [selectedCases, setSelectedCases] = useState<Set<string>>(new Set());
  const [testcaseSearch, setTestcaseSearch] = useState("");
  const [testcaseResultFilter, setTestcaseResultFilter] = useState<"all" | TestResult>("all");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isMobile, setIsMobile] = useState(() => window.innerWidth <= MOBILE_SIDEBAR_BREAKPOINT);
  const [sidebarOpen, setSidebarOpen] = useState(() => window.innerWidth > MOBILE_SIDEBAR_BREAKPOINT);
  const [documentVisible, setDocumentVisible] = useState(() => document.visibilityState !== "hidden");
  const waveformCache = useRef(new Map<string, WaveformDetails>());
  const waveformRequest = useRef<AbortController | null>(null);
  const selectedRegressionId = useRef<string | null>(null);

  const refreshOverview = useCallback(async (activeProject: Project) => {
    const [nextDashboard, nextRegressions] = await Promise.all([
      platformApi.dashboard(activeProject.id),
      platformApi.regressions(activeProject.id)
    ]);
    setDashboard(nextDashboard);
    setRegressions(nextRegressions);
    setSelectedRegression((current) => {
      const next = nextRegressions.find((regression) => regression.id === current?.id) ?? nextRegressions[0] ?? null;
      selectedRegressionId.current = next?.id ?? null;
      return next;
    });
  }, []);

  const refreshTestcases = useCallback(async (activeProject: Project) => {
    const nextTestcases = await platformApi.testcases(activeProject.id);
    setTestcases(nextTestcases);
    setTestcasesLoaded(true);
  }, []);

  const refreshWaveforms = useCallback(async (activeProject: Project) => {
    const nextWaveforms = await platformApi.waveforms(activeProject.id);
    setWaveforms(nextWaveforms);
    setWaveformsLoaded(true);
  }, []);

  const selectRegression = useCallback((regression: Regression) => {
    selectedRegressionId.current = regression.id;
    setSelectedRegression(regression);
    setSimulations([]);
  }, []);

  useEffect(() => {
    let cancelled = false;
    const bootstrap = async () => {
      try {
        const activeProject = (await platformApi.projects())[0];
        if (!activeProject) throw new Error("平台尚未创建验证项目。");
        if (cancelled) return;
        setProject(activeProject);
        await refreshOverview(activeProject);
        if (!cancelled) setError(null);
      } catch (reason) {
        if (!cancelled) setError(apiErrorMessage(reason, "无法连接验证平台 API。"));
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    void bootstrap();
    return () => { cancelled = true; };
  }, [refreshOverview]);

  useEffect(() => {
    const onVisibilityChange = () => setDocumentVisible(document.visibilityState !== "hidden");
    document.addEventListener("visibilitychange", onVisibilityChange);
    return () => document.removeEventListener("visibilitychange", onVisibilityChange);
  }, []);

  useEffect(() => {
    const mediaQuery = window.matchMedia(`(max-width: ${MOBILE_SIDEBAR_BREAKPOINT}px)`);
    const onBreakpointChange = (event: MediaQueryListEvent) => {
      setIsMobile(event.matches);
      setSidebarOpen(!event.matches);
    };
    mediaQuery.addEventListener("change", onBreakpointChange);
    return () => mediaQuery.removeEventListener("change", onBreakpointChange);
  }, []);

  useEffect(() => {
    if (!isMobile || !sidebarOpen) return;
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") setSidebarOpen(false);
    };
    window.addEventListener("keydown", closeOnEscape);
    document.body.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", closeOnEscape);
      document.body.style.overflow = "";
    };
  }, [isMobile, sidebarOpen]);

  // Secondary pages fetch only when first opened, rather than on the dashboard refresh cadence.
  useEffect(() => {
    if (!project || view !== "testcases" || testcasesLoaded) return;
    void refreshTestcases(project).catch((reason: unknown) => setError(apiErrorMessage(reason, "无法读取测试用例。")));
  }, [project, refreshTestcases, testcasesLoaded, view]);

  useEffect(() => {
    if (!project || view !== "waveforms" || waveformsLoaded) return;
    void refreshWaveforms(project).catch((reason: unknown) => setError(apiErrorMessage(reason, "无法读取波形目录。")));
  }, [project, refreshWaveforms, view, waveformsLoaded]);

  useEffect(() => {
    if (view !== "regressions" || !selectedRegression || selectedRegression.status === "queued") return;
    const regressionId = selectedRegression.id;
    const request = new AbortController();
    void platformApi.regressionProgress(regressionId, { signal: request.signal })
      .then((progress) => {
        if (request.signal.aborted || selectedRegressionId.current !== regressionId) return;
        setSelectedRegression(progress.regression);
        setRegressions((current) => current.map((regression) => regression.id === regressionId ? progress.regression : regression));
        setSimulations(progress.simulations);
      })
      .catch((reason: unknown) => {
        if (!request.signal.aborted) setError(apiErrorMessage(reason, "无法读取回归任务详情。"));
      });
    return () => request.abort();
  }, [selectedRegression?.id, selectedRegression?.status, view]);

  useEffect(() => {
    if (
      view !== "regressions" ||
      !project ||
      !selectedRegression ||
      selectedRegression.status !== "queued" ||
      !documentVisible
    ) return;
    const regressionId = selectedRegression.id;
    let active = true;
    const eventSource = new EventSource(`/api/v1/regressions/${regressionId}/events`);
    eventSource.onmessage = (event) => {
      try {
        const progress = JSON.parse(event.data) as { regression: Regression; simulations: Simulation[] };
        const { regression: updated, simulations: nextSimulations } = progress;
        if (!active || selectedRegressionId.current !== updated.id) return;
        setSelectedRegression(updated);
        setRegressions((current) => current.map((regression) => regression.id === updated.id ? updated : regression));
        setSimulations(nextSimulations);
        if (updated.status !== "queued") {
          active = false;
          eventSource.close();
          void refreshOverview(project);
          if (testcasesLoaded) void refreshTestcases(project);
        }
        setError(null);
      } catch (reason) {
        setError(apiErrorMessage(reason, "无法解析实时回归进度。"));
      }
    };
    eventSource.onerror = () => {
      if (!active) return;
      active = false;
      eventSource.close();
      setError("实时回归连接中断，请使用刷新按钮读取最新结果。");
    };
    return () => {
      active = false;
      eventSource.close();
    };
  }, [documentVisible, project, refreshOverview, refreshTestcases, selectedRegression?.id, selectedRegression?.status, testcasesLoaded, view]);

  useEffect(() => () => waveformRequest.current?.abort(), []);

  const runCases = async (cases: string[]) => {
    if (!project) return;
    try {
      const regression = await platformApi.startRegression(project.id, cases);
      setRegressions((current) => [regression, ...current.filter((item) => item.id !== regression.id)]);
      selectRegression(regression);
      setView("regressions");
      setError(null);
    } catch (reason) {
      setError(apiErrorMessage(reason, "无法启动回归。"));
    }
  };

  const refreshRegressionPage = async () => {
    if (!project) return;
    const regressionId = selectedRegressionId.current;
    try {
      await refreshOverview(project);
      if (regressionId) {
        const progress = await platformApi.regressionProgress(regressionId);
        if (selectedRegressionId.current === regressionId) {
          setSelectedRegression(progress.regression);
          setRegressions((current) => current.map((regression) => regression.id === regressionId ? progress.regression : regression));
          setSimulations(progress.simulations);
        }
      }
      setError(null);
    } catch (reason) {
      setError(apiErrorMessage(reason, "无法刷新回归数据。"));
    }
  };

  const selectWaveform = async (name: string) => {
    if (!project || selectedWaveform?.name === name) return;
    const cached = waveformCache.current.get(name);
    setWaveformSearch("");
    if (cached) {
      setSelectedWaveform(cached);
      return;
    }

    waveformRequest.current?.abort();
    const controller = new AbortController();
    waveformRequest.current = controller;
    try {
      const waveform = await platformApi.waveform(project.id, name, { signal: controller.signal });
      if (controller.signal.aborted) return;
      waveformCache.current.set(name, waveform);
      setSelectedWaveform(waveform);
      setError(null);
    } catch (reason) {
      if (!(reason instanceof DOMException && reason.name === "AbortError")) {
        setError(apiErrorMessage(reason, "无法读取波形。"));
      }
    }
  };

  const uploadWaveform = async (file: File) => {
    if (!project) return;
    setImportingWaveform(true);
    try {
      const waveform = await platformApi.uploadWaveform(project.id, file);
      waveformCache.current.delete(waveform.name);
      await refreshWaveforms(project);
      const details = await platformApi.waveform(project.id, waveform.name);
      waveformCache.current.set(waveform.name, details);
      setWaveformSearch("");
      setSelectedWaveform(details);
      setError(null);
    } catch (reason) {
      setError(apiErrorMessage(reason, "无法导入 VCD 文件。"));
    } finally {
      setImportingWaveform(false);
    }
  };

  const toggleCase = (name: string) => setSelectedCases((current) => {
    const next = new Set(current);
    next.has(name) ? next.delete(name) : next.add(name);
    return next;
  });
  const setVisibleCaseSelection = (names: string[], selected: boolean) => setSelectedCases((current) => {
    const next = new Set(current);
    names.forEach((name) => selected ? next.add(name) : next.delete(name));
    return next;
  });
  const navigateTo = (nextView: View) => {
    setView(nextView);
    if (isMobile) setSidebarOpen(false);
  };
  const running = regressions.some((regression) => regression.status === "queued");
  const currentTitle = navigation.find((item) => item.view === view)?.label ?? "仪表盘";
  const filteredWaveform = useMemo(() => {
    if (!selectedWaveform) return null;
    const query = waveformSearch.trim().toLocaleLowerCase();
    if (!query) return selectedWaveform;
    return {
      ...selectedWaveform,
      matched_signals: selectedWaveform.matched_signals.filter((signal) => signal.name.toLocaleLowerCase().includes(query))
    };
  }, [selectedWaveform, waveformSearch]);

  const page = useMemo(() => {
    if (!dashboard || !project) return null;
    if (view === "testcases") return <TestCasesPage cases={testcases} selected={selectedCases} search={testcaseSearch} resultFilter={testcaseResultFilter} running={running} onToggle={toggleCase} onSetVisibleSelection={setVisibleCaseSelection} onSearch={setTestcaseSearch} onResultFilter={setTestcaseResultFilter} onRunSelected={() => void runCases([...selectedCases])} />;
    if (view === "regressions") return <RegressionsPage regressions={regressions} selectedRegression={selectedRegression} simulations={simulations} running={running} onRunAll={() => void runCases(["all"])} onSelect={selectRegression} onRefresh={() => void refreshRegressionPage()} />;
    if (view === "waveforms") return <WaveformsPage waveforms={waveforms} selected={filteredWaveform} search={waveformSearch} onSearch={setWaveformSearch} onSelect={(name) => void selectWaveform(name)} importing={importingWaveform} onUpload={(file) => void uploadWaveform(file)} />;
    return <DashboardPage dashboard={dashboard} regressions={regressions} running={running} onRunAll={() => void runCases(["all"])} />;
  }, [dashboard, filteredWaveform, importingWaveform, project, regressions, running, selectRegression, selectedCases, selectedRegression, simulations, testcaseResultFilter, testcaseSearch, testcases, view, waveformSearch, waveforms]);

  if (loading) return <LoadingState />;
  return <div className={`app-shell ${sidebarOpen ? "sidebar-open" : "sidebar-collapsed"}`}>
    <button className="sidebar-backdrop" aria-label="关闭导航" onClick={() => setSidebarOpen(false)} />
    <aside className="sidebar" aria-label="主导航">
      <div className="brand">
        <div className="brand-mark"><ChartNoAxesCombined size={20} /></div>
        {sidebarOpen && <div><strong>Chip DV</strong><span>Verification Platform</span></div>}
      </div>
      <nav>
        {navigation.map((item) => {
          const Icon = item.icon;
          return <button key={item.view} className={view === item.view ? "nav-active" : ""} onClick={() => navigateTo(item.view)} title={item.label} aria-current={view === item.view ? "page" : undefined}><Icon size={18} />{sidebarOpen && <span>{item.label}</span>}</button>;
        })}
      </nav>
      <div className="sidebar-footer">
        <button
          className="sidebar-toggle"
          onClick={() => setSidebarOpen((value) => !value)}
          aria-label={sidebarOpen ? (isMobile ? "关闭导航" : "折叠导航") : "展开导航"}
          aria-expanded={sidebarOpen}
          title={sidebarOpen ? (isMobile ? "关闭导航" : "折叠导航") : "展开导航"}
        >
          {isMobile ? <X size={18} /> : sidebarOpen ? <PanelLeftClose size={18} /> : <PanelLeftOpen size={18} />}
        </button>
      </div>
    </aside>
    <main>
      <header className="topbar">
        <button className="menu-button" onClick={() => setSidebarOpen((value) => !value)} aria-label={sidebarOpen ? "关闭导航" : "打开导航"} aria-expanded={sidebarOpen} title={sidebarOpen ? "关闭导航" : "打开导航"}><Menu size={20} /></button>
        <div className="breadcrumb"><span>Chip DV Platform</span><ChevronRight size={14} /><strong>{currentTitle}</strong></div>
        <div className="topbar-right"><span className="connection-dot" /><span>API 已连接</span></div>
      </header>
      {error && <div className="error-banner">{error}</div>}
      <div className="page-content">{page}</div>
    </main>
  </div>;
}
