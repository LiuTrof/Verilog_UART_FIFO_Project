import type {
  Dashboard,
  Project,
  Regression,
  RegressionProgress,
  Simulation,
  TestCase,
  WaveformDetails,
  WaveformSummary
} from "./types";

const API_ROOT = "/api/v1";

interface RequestOptions {
  signal?: AbortSignal;
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${API_ROOT}${path}`, {
    headers: { "Content-Type": "application/json", ...init?.headers },
    ...init
  });
  if (!response.ok) {
    const body = (await response.json().catch(() => ({ detail: response.statusText }))) as { detail?: string };
    throw new Error(body.detail ?? "Platform API request failed.");
  }
  return response.json() as Promise<T>;
}

export const platformApi = {
  projects: (options?: RequestOptions): Promise<Project[]> => request("/projects", options),
  dashboard: (projectId: number, options?: RequestOptions): Promise<Dashboard> =>
    request(`/projects/${projectId}/dashboard`, options),
  testcases: (projectId: number, options?: RequestOptions): Promise<TestCase[]> =>
    request(`/projects/${projectId}/testcases`, options),
  regressions: (projectId: number, options?: RequestOptions): Promise<Regression[]> =>
    request(`/projects/${projectId}/regressions`, options),
  regression: (regressionId: string, options?: RequestOptions): Promise<Regression> =>
    request(`/regressions/${regressionId}`, options),
  regressionProgress: (regressionId: string, options?: RequestOptions): Promise<RegressionProgress> =>
    request(`/regressions/${regressionId}/progress`, options),
  simulations: (regressionId: string, options?: RequestOptions): Promise<Simulation[]> =>
    request(`/regressions/${regressionId}/simulations`, options),
  waveforms: (projectId: number, options?: RequestOptions): Promise<WaveformSummary[]> =>
    request(`/projects/${projectId}/waveforms`, options),
  waveform: (projectId: number, name: string, options?: RequestOptions): Promise<WaveformDetails> =>
    request(`/projects/${projectId}/waveforms/${encodeURIComponent(name)}`, options),
  uploadWaveform: async (projectId: number, file: File): Promise<WaveformSummary> => {
    const form = new FormData();
    form.append("file", file);
    const response = await fetch(`${API_ROOT}/projects/${projectId}/waveforms`, {
      method: "POST",
      body: form
    });
    if (!response.ok) {
      const body = (await response.json().catch(() => ({ detail: response.statusText }))) as { detail?: string };
      throw new Error(body.detail ?? "Waveform upload failed.");
    }
    return response.json() as Promise<WaveformSummary>;
  },
  startRegression: (projectId: number, cases: string[]): Promise<Regression> =>
    request(`/projects/${projectId}/regressions`, {
      method: "POST",
      body: JSON.stringify({ cases, simulator: "auto" })
    })
};
