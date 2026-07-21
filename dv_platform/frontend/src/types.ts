export type RegressionStatus = "queued" | "passed" | "failed";
export type TestResult = "not_run" | "passed" | "failed";

export interface Project {
  id: number;
  name: string;
  description: string;
  version: string;
  created_at: string;
}

export interface TestCase {
  id: number;
  project_id: number;
  name: string;
  description: string;
  owner: string;
  expected_checks: number;
  status: string;
  result: TestResult;
}

export interface Regression {
  id: string;
  project_id: number;
  simulator: string;
  status: RegressionStatus;
  started_at: string;
  finished_at: string | null;
  total_cases: number;
  passed_cases: number;
  report_path: string | null;
}

export interface Simulation {
  id: number;
  regression_id: string;
  testcase_id: number;
  status: "passed" | "failed";
  runtime_seconds: number;
  checked_bytes: number | null;
  error_count: number | null;
  pending_bytes: number | null;
  log_path: string;
  failure_reason: string | null;
  testcase_name: string | null;
}

export interface RegressionProgress {
  regression: Regression;
  simulations: Simulation[];
}

export interface Coverage {
  line_coverage: number | null;
  branch_coverage: number | null;
  fsm_coverage: number | null;
  functional_coverage: number | null;
  source: string | null;
}

export interface Dashboard {
  project: Project;
  total_testcases: number;
  passed_testcases: number;
  pass_rate: number;
  failed_testcases: number;
  latest_regression: Regression | null;
  coverage: Coverage;
}

export interface WaveformSummary {
  name: string;
  size_bytes: number;
  modified_at: string;
  signal_count: number;
  end_time: number | null;
  timescale: string | null;
}

export interface WaveformDetails {
  name: string;
  signal_count: number;
  matched_signals: Array<{ name: string; identifier: string; width: number }>;
  query: string;
  preview: string;
  end_time: number | null;
  timescale: string | null;
}
