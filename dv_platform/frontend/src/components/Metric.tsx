interface MetricProps {
  label: string;
  value: string | number;
  hint: string;
  tone: "cyan" | "green" | "amber" | "red";
}

export function Metric({ label, value, hint, tone }: MetricProps) {
  return (
    <section className={`metric metric-${tone}`}>
      <span>{label}</span>
      <strong>{value}</strong>
      <small>{hint}</small>
    </section>
  );
}
