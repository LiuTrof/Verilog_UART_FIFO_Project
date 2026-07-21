import type { RegressionStatus, TestResult } from "../types";

type BadgeStatus = RegressionStatus | TestResult | "ready";

interface StatusBadgeProps {
  status: BadgeStatus;
}

const labels: Record<BadgeStatus, string> = {
  queued: "运行中",
  passed: "通过",
  failed: "失败",
  not_run: "未运行",
  ready: "就绪"
};

export function StatusBadge({ status }: StatusBadgeProps) {
  return <span className={`status-badge status-${status}`}>{labels[status]}</span>;
}
