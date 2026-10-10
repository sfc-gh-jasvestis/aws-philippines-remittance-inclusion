'use client';

import { useEffect, useState } from 'react';
import { AppLayout } from '@/components/AppLayout';
import { KPICard } from '@/components/KPICard';
import { Chart } from '@/components/Chart';
import { DataTable } from '@/components/DataTable';
import { AskAI } from '@/components/AskAI';
import { ActionMemo } from '@/components/ActionMemo';

interface InclusionData {
  platform: 'snowflake' | 'aws';
  kpiCards: { title: string; value: string }[];
  timeseries: { period: string; blockers: number | null; dropouts: number | null }[];
  categories: { category: string; blockers: number | null; dropouts: number | null }[];
  entities: Record<string, string | number | null>[];
  followupRisk: { name: string; completion: number; dropouts: number }[];
  sourceWatermark: string | null;
  rawWatermark: string | null;
  requestedAt: string;
  stale: boolean;
  pipelineBehind: boolean;
  risk: Record<string, string | number | null>[];
  holdout: { n: number | null; baseRate: number | null; precision: number | null; recall: number | null } | null;
  forecast: { period: string; value: number | null; lower: number | null; upper: number | null }[];
  live: Record<string, string | number | null>[];
  liveSummary: { n: number | null; blockers: number | null; lastLoaded: string | null; medianLagSeconds: number | null };
  anomalies: Record<string, string | number | null>[];
  alerts: Record<string, string | number | null>[];
}

const pct = (value: number | null) => (value === null ? 'n/a' : `${(value * 100).toFixed(0)}%`);

export default function HomePage() {
  const [data, setData] = useState<InclusionData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError(null);
    setData(null);
    fetch('/api/data', { cache: 'no-store', signal: controller.signal })
      .then(async (response) => {
        if (!response.ok) throw new Error('Data request failed');
        const payload = await response.json();
        if (!Array.isArray(payload.kpiCards) || !Array.isArray(payload.entities)) throw new Error('Invalid contract');
        return payload;
      })
      .then(setData)
      .catch(() => {
        if (!controller.signal.aborted) setError('Snowflake data is unavailable. No fallback values are displayed.');
      })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [attempt]);

  const isAws = (data?.platform ?? 'aws') === 'aws';
  const awsDiagram = { key: 'aws', title: 'AWS + Snowflake', src: '/architecture-aws.html' };
  const sfDiagram = { key: 'snowflake', title: 'Snowflake Only', src: '/architecture-snowflake.html' };
  const diagrams = isAws ? [awsDiagram, sfDiagram] : [sfDiagram, awsDiagram];
  const kpiVal = (title: string) => data?.kpiCards.find((card) => card.title === title)?.value ?? 'Unavailable';
  const executive = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {['Blocker-Free Pickup Rate', 'Savings Accounts Opened', 'Pickup-to-Account Conversion', 'Abandoned-Application Blockers'].map((title) => (
          <KPICard key={title} title={title} value={kpiVal(title)} status="neutral" />
        ))}
      </div>
      <p className="text-sm text-slate-600">Blocker-free pickup rate = remittance pickups not touched by an onboarding blocker / remittance pickups. Pickup-to-account conversion = basic savings accounts opened / remittance pickups. Blocker dropout rate = abandoned applications / onboarding blockers.</p>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Chart data={data?.timeseries ?? []} type="line" xKey="period"
          yKeys={[{ key: 'blockers', name: 'Onboarding blockers' }, { key: 'dropouts', name: 'Abandoned applications' }]} title="Daily Onboarding Blockers" />
        <Chart data={data?.categories ?? []} type="bar" xKey="category"
          yKeys={[{ key: 'blockers', name: 'Blockers' }, { key: 'dropouts', name: 'Abandoned' }]} title="Blockers and Abandoned Applications by Blocker Type" />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Site' }, { key: 'region', header: 'City' }, { key: 'category', header: 'Format' },
        { key: 'tier', header: 'Risk tier' }, { key: 'pickups', header: 'Pickups' }, { key: 'opened', header: 'Accounts opened' }, { key: 'blockers', header: 'Blockers' },
        { key: 'dropouts', header: 'Abandoned' }, { key: 'breaches', header: 'SLA breaches' }, { key: 'payout', header: 'Payouts (PHP M)' },
      ]} data={data?.entities ?? []} title="Site observations, last 90 days" />
    </div>
  );
  const predictive = (
    <div className="space-y-4">
      <h2 className="font-semibold">7-day abandoned-application risk and blocker-volume forecast</h2>
      <p className="text-sm text-slate-600">
        Snowflake ML classification predicts the probability that a site has an onboarding blocker that ends in an abandoned application in the next 7 days,
        from eKYC error rate, average onboarding time, recent abandoned applications, site risk tier, partner tenure and format.
      </p>
      {data?.holdout ? (
        <p role="status" className="text-sm text-slate-700">
          Out-of-time holdout ({data.holdout.n} site-days): precision {pct(data.holdout.precision)} and recall{' '}
          {pct(data.holdout.recall)} at a 0.5 threshold, versus a {pct(data.holdout.baseRate)} base rate.
        </p>
      ) : (
        <p role="status">Model outputs are not deployed. Run snowflake/05_ml.sql.</p>
      )}
      <DataTable columns={[
        { key: 'id', header: 'Site' }, { key: 'band', header: 'Risk band' },
        { key: 'probability', header: 'P(abandoned application in 7 days)' }, { key: 'scoredAsOf', header: 'Scored as of' },
      ]} data={data?.risk ?? []} title="Abandoned-application risk by site" />
      <Chart data={data?.forecast ?? []} type="line" xKey="period"
        yKeys={[{ key: 'value', name: 'Forecast' }, { key: 'lower', name: 'Lower' }, { key: 'upper', name: 'Upper' }]}
        title="Programme-wide blocker forecast, next 14 days (blockers per day)" />
      <DataTable columns={[
        { key: 'id', header: 'Site' }, { key: 'date', header: 'Date' }, { key: 'errorRate', header: 'eKYC error rate (%)' },
        { key: 'expected', header: 'Expected' }, { key: 'upper', header: 'Upper bound' },
      ]} data={data?.anomalies ?? []} title="eKYC error-rate anomalies, last 15 days (Snowflake ML anomaly detection, trained on the prior 75 days)" />
    </div>
  );
  const liveTab = (
    <div className="space-y-4">
      <h2 className="font-semibold">{isAws ? 'Live pickups: Amazon Data Firehose to S3 to Snowpipe' : 'Live pickups: Snowflake-native simulator'}</h2>
      <p className="text-sm text-slate-600">
        {isAws
          ? 'Simulated remittance pickup events are sent to the Firehose stream ph-remittance-inclusion-pickups (aws/publish_pickups.py). Firehose writes batches to S3, and Snowpipe auto-ingest loads them into RAW.LIVE_PICKUPS.'
          : 'CALL APP.SIMULATE_PICKUPS(n) inserts simulated remittance pickup events directly into RAW.LIVE_PICKUPS (or resume APP.TASK_SIMULATE_PICKUPS for a feed every minute). This simulates a pickup event feed; it is not Snowpipe Streaming.'}
        {' '}The alert APP.LIVE_BLOCKER_ALERT logs BLOCKER events and emails the on-call inclusion operations analyst.
      </p>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KPICard title="Pickup events loaded" value={String(data?.liveSummary?.n ?? 'n/a')} />
        <KPICard title="BLOCKER events" value={String(data?.liveSummary?.blockers ?? 'n/a')} />
        <KPICard title={isAws ? 'Median send to table lag (s)' : 'Median generated to table lag (s)'} value={String(data?.liveSummary?.medianLagSeconds ?? 'n/a')} />
        <KPICard title="Last load" value={data?.liveSummary?.lastLoaded ?? 'none'} />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Site' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'amount', header: 'Amount (PHP)' },
        { key: 'onboardMin', header: 'Onboarding time (min)' }, { key: 'status', header: 'Status' }, { key: 'loadedAt', header: 'Loaded' },
      ]} data={data?.live ?? []} title="Latest 25 pickup events" />
      <DataTable columns={[
        { key: 'id', header: 'Site' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'amount', header: 'Amount (PHP)' },
        { key: 'onboardMin', header: 'Onboarding time (min)' }, { key: 'hint', header: 'Action hint' },
      ]} data={data?.alerts ?? []} title="Alert log" />
    </div>
  );
  const planning = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <KPICard title="Dormant-Account Follow-Up Completion" value={kpiVal('Dormant-Account Follow-Up Completion')} />
        <KPICard title="Partner Document Coverage" value={kpiVal('Partner Document Coverage')} />
        <KPICard title="Partner Documents Pending" value={kpiVal('Partner Documents Pending')} />
      </div>
      <Chart data={data?.followupRisk ?? []} type="scatter" xKey="completion" xName="dormant-account follow-up completion"
        yKeys={[{ key: 'dropouts', name: 'Abandoned applications' }]} yDomain={[0, 'auto']}
        title="Dormant-account follow-up completion (%) vs abandoned applications by site" />
      <p className="text-sm text-slate-600">Synthetic associations are not evidence that follow-ups prevented abandoned applications.</p>
      <ActionMemo persona={{ name: 'Marivic Dela Rosa-Santos', role: 'Head of Remittance Inclusion Programme (fictional persona)' }} context={{}}
        onGenerate={async () => {
          const r = await fetch('/api/ask', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ mode: 'memo' }) });
          if (!r.ok) throw new Error('memo failed');
          const j = await r.json();
          return { subject: 'Draft inclusion programme actions (synthetic data, human review required)', body: j.answer, urgency: 'review', actions: [] };
        }} />
      <p role="status" className="text-sm text-slate-600">{isAws ? 'Draft generated by Amazon Bedrock (Claude) through a Snowflake external-access function' : 'Draft generated by Snowflake Cortex AI_COMPLETE (Claude Sonnet 4.5)'}, from the KPI, site, blocker-type and risk tables only. No notification is sent.</p>
    </div>
  );
  const ai = (
    <div className="space-y-4">
      <p role="status">Answers come from the Cortex Agent APP.INCLUSION_OPS_AGENT. It uses Cortex Analyst over the semantic view APP.INCLUSION_ANALYTICS for metrics, and Cortex Search over synthetic onboarding-blocker SOPs for procedures. The generated SQL is shown with each answer.</p>
      <div className="h-[500px]">
        <AskAI title="Ask the inclusion operations agent" mode="advisor" sampleQuestions={['Which 3 sites have the most abandoned applications?', 'Which sites are high risk this week and what SOP applies?', 'What is the blocker dropout rate by blocker type?']}
          onSubmit={async (question) => {
            const r = await fetch('/api/agent', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ question }) });
            if (!r.ok) throw new Error('agent failed');
            const j = await r.json();
            const cites = j.sops?.length ? `\n\nSOPs: ${j.sops.join(', ')}` : '';
            return { answer: `${j.answer}${cites}`, sql: j.sql ?? undefined };
          }} />
      </div>
    </div>
  );
  const architecture = (
    <div className="space-y-4">
      {diagrams.map((d, i) => (
        <div key={d.key} className="space-y-2">
          <h2 className="font-semibold">Architecture: {d.title}{i === 0 ? ' (this deployment)' : ''}</h2>
          <iframe src={d.src} title={`${d.title} architecture diagram`} className="h-[620px] w-full rounded border border-slate-200" />
          <p className="text-sm text-slate-600">Hover a component for details. <a className="underline" href={d.src} target="_blank" rel="noreferrer">Open full screen</a></p>
        </div>
      ))}
      <h2 className="font-semibold">Implementation status</h2>
      <p>Core source: 40 synthetic remittance pickup sites of a fictional Philippine rural bank inclusion programme in 5 cities, daily site observations and partner accreditation documents. Curated dynamic tables compute numerator/denominator metrics and are suspended after on-demand initialization.</p>
      <p>Application: Next.js server queries the explicit curated contract. Request time and source observation watermark are separate.</p>
      <p>ML: SNOWFLAKE.ML.CLASSIFICATION abandoned-application risk model evaluated on a time-based holdout, plus a 14-day blocker-volume FORECAST with prediction intervals.</p>
      <p>ML: ANOMALY_DETECTION flags eKYC error rate outliers per site over the last 15 days.</p>
      <p>AI: Cortex Agent (Cortex Analyst over a semantic view, plus Cortex Search over SOPs) answers questions. The action memo uses {isAws ? 'Amazon Bedrock Claude through an external-access UDF' : 'Cortex AI_COMPLETE (Claude Sonnet 4.5)'}.</p>
      {isAws ? (
        <>
          <p>AWS ingestion: Amazon Data Firehose to S3 to Snowpipe auto-ingest (SQS) into RAW.LIVE_PICKUPS, with a Snowflake alert and email on BLOCKER events.</p>
          <p>QuickSight: Snowflake DIRECT_QUERY dashboard (daily blockers, abandoned applications by site, abandoned-application risk) through a PAT-only service user, with a Q topic.</p>
        </>
      ) : (
        <>
          <p>Ingestion: APP.SIMULATE_PICKUPS inserts simulated remittance pickup events into RAW.LIVE_PICKUPS, with a Snowflake alert and email on BLOCKER events. No AWS account is used.</p>
          <p>BI: this SPCS app is the dashboard; natural-language questions go to the Cortex Agent.</p>
        </>
      )}
      <p>Orchestration: the task graph APP.TASK_REFRESH_CURATED, then TASK_RESCORE_RISK, runs on demand. Alerts and tasks stay suspended between demos.</p>
    </div>
  );
  const tabs = [
    { id: 'executive-cockpit', label: 'Executive Cockpit', icon: '', content: executive },
    { id: 'predictive', label: 'Predictive', icon: '', content: predictive },
    { id: 'planning', label: 'Controls', icon: '', content: planning },
    { id: 'live', label: 'Live Pickups', icon: '', content: liveTab },
    { id: 'ask-ai', label: 'Ask AI', icon: '', content: ai },
    { id: 'architecture', label: 'Architecture & Data', icon: '', content: architecture },
  ].map((tab) => ({ ...tab, content: tab.id === 'architecture' ? tab.content : (
    <div className="space-y-4">
      <p className="text-sm text-slate-600">Synthetic demo data for the remittance inclusion programme of a fictional Philippine rural bank. On-demand snapshots are not live customer operations.</p>
      {loading ? <p role="status">Loading Snowflake data...</p> : error ? (
        <div role="alert" className="rounded border border-red-200 p-4">
          <p>{error}</p>
          <button className="mt-3 rounded border px-3 py-2" onClick={() => setAttempt((value) => value + 1)}>Retry data connection</button>
        </div>
      ) : !data?.entities.length ? <p role="status">No site observations are available in this snapshot.</p> : (
        <>
          <p className="text-sm">Observation watermark: {data.sourceWatermark ?? 'Unavailable'}. Request time: {data.requestedAt}.</p>
          {(data.stale || data.pipelineBehind) && <p role="status" className="text-amber-700">Stale or lagging snapshot. Refresh the on-demand pipeline before presenting current results.</p>}
          {tab.content}
        </>
      )}
    </div>
  ) }));
  return <AppLayout title="Philippines Remittance Inclusion Operations" tabs={tabs} />;
}
