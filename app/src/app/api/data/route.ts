import { NextResponse } from 'next/server';
import { demoPlatform } from '@/lib/platform';
import { executeQuery } from '@/lib/snowflake';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export async function GET() {
  try {
    const [kpis, trend, types, sites, freshness, risk, holdout, forecast, live, liveSummary, anomalies, alerts] = await Promise.all([
      executeQuery<{ TITLE: string; DISPLAY: string; STATUS: string }>(
        'SELECT TITLE, DISPLAY, STATUS FROM CURATED.KPI_SUMMARY ORDER BY SORT_ORDER'),
      executeQuery<{ PERIOD: string; BLOCKERS: number | null; DROPOUTS: number | null }>(`
        SELECT TO_CHAR(METRIC_DATE, 'YYYY-MM-DD') AS PERIOD,
               BLOCKER_COUNT AS BLOCKERS, DROPOUT_COUNT AS DROPOUTS
        FROM CURATED.TREND_ANALYSIS ORDER BY METRIC_DATE`),
      executeQuery<{ BLOCKER_TYPE: string; BLOCKERS: number; DROPOUTS: number }>(`
        SELECT BLOCKER_TYPE, BLOCKER_COUNT AS BLOCKERS, DROPOUT_COUNT AS DROPOUTS
        FROM CURATED.BLOCKER_SUMMARY ORDER BY DROPOUT_COUNT DESC, BLOCKER_COUNT DESC`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, ENTITY_NAME, REGION, CATEGORY, RISK_TIER, EVENT_COUNT, PICKUP_COUNT, ACCOUNTS_OPENED, BLOCKER_COUNT,
               DROPOUT_COUNT, SLA_BREACH_COUNT, BLOCKER_DROPOUT_PCT, FOLLOWUP_COMPLETION_PCT, ROUND(PAYOUT_PHP / 1e6, 2) AS PAYOUT_PHP_M
        FROM CURATED.PERFORMANCE_SUMMARY ORDER BY ENTITY_ID LIMIT 200`),
      executeQuery<{ RAW_WATERMARK: string | null; CURATED_WATERMARK: string | null }>(`
        SELECT (SELECT TO_CHAR(MAX(EVENT_DATE), 'YYYY-MM-DD') FROM RAW.SITE_DAILY) AS RAW_WATERMARK,
               (SELECT TO_CHAR(MAX(METRIC_DATE), 'YYYY-MM-DD') FROM CURATED.TREND_ANALYSIS) AS CURATED_WATERMARK`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, TO_CHAR(SCORED_AS_OF, 'YYYY-MM-DD') AS SCORED_AS_OF, DROPOUT_PROB_7D, RISK_BAND
        FROM ML.DROPOUT_RISK_SCORES ORDER BY DROPOUT_PROB_7D DESC`),
      executeQuery<Record<string, string | number | null>>(
        'SELECT N, BASE_RATE, PRECISION_AT_50, RECALL_AT_50 FROM ML.DROPOUT_RISK_HOLDOUT_METRICS'),
      executeQuery<Record<string, string | number | null>>(`
        SELECT TO_CHAR(FORECAST_DATE, 'YYYY-MM-DD') AS PERIOD, BLOCKER_COUNT, LOWER_BOUND, UPPER_BOUND
        FROM ML.BLOCKER_FORECAST ORDER BY FORECAST_DATE`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT SITE_ID, TO_CHAR(EVENT_TS, 'YYYY-MM-DD HH24:MI:SS') AS EVENT_TS, ROUND(AMOUNT_PHP, 0) AS AMOUNT_PHP,
               ONBOARD_MINUTES, STATUS, TO_CHAR(LOADED_AT, 'YYYY-MM-DD HH24:MI:SS TZH:TZM') AS LOADED_AT
        FROM RAW.LIVE_PICKUPS ORDER BY EVENT_TS DESC LIMIT 25`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT COUNT(*) AS N, COUNT_IF(STATUS = 'BLOCKER') AS BLOCKERS,
               TO_CHAR(MAX(LOADED_AT), 'YYYY-MM-DD HH24:MI:SS TZH:TZM') AS LAST_LOADED,
               ROUND(MEDIAN(DATEDIFF('second', SENT_TS, CONVERT_TIMEZONE('UTC', LOADED_AT)::TIMESTAMP_NTZ)), 0) AS MEDIAN_LAG_S
        FROM RAW.LIVE_PICKUPS`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, TO_CHAR(EVENT_DATE, 'YYYY-MM-DD') AS EVENT_DATE, ROUND(EKYC_ERROR, 2) AS EKYC_ERROR,
               ROUND(EXPECTED, 2) AS EXPECTED, ROUND(UPPER_BOUND, 2) AS UPPER_BOUND
        FROM ML.EKYC_ERROR_ANOMALIES WHERE IS_ANOMALY ORDER BY EVENT_DATE DESC, ENTITY_ID LIMIT 50`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT SITE_ID, TO_CHAR(EVENT_TS, 'YYYY-MM-DD HH24:MI:SS') AS EVENT_TS, ROUND(AMOUNT_PHP, 0) AS AMOUNT_PHP,
               ONBOARD_MINUTES, SOP_HINT
        FROM APP.ALERT_LOG ORDER BY ALERTED_AT DESC, EVENT_TS DESC LIMIT 25`),
    ]);
    const numberOrNull = (value: unknown): number | null => {
      if (value === null || value === undefined) return null;
      const numeric = Number(value);
      if (!Number.isFinite(numeric)) throw new Error('Non-numeric measure in curated contract');
      return numeric;
    };
    const watermark = freshness[0]?.CURATED_WATERMARK ?? null;
    const ageDays = watermark ? (Date.now() - Date.parse(`${watermark}T00:00:00Z`)) / 86400000 : null;
    return NextResponse.json({
      platform: demoPlatform(),
      kpiCards: kpis.map((row) => ({ title: row.TITLE, value: row.DISPLAY, status: row.STATUS })),
      timeseries: trend.map((row) => ({ period: row.PERIOD, blockers: numberOrNull(row.BLOCKERS), dropouts: numberOrNull(row.DROPOUTS) })),
      categories: types.map((row) => ({ category: row.BLOCKER_TYPE, blockers: numberOrNull(row.BLOCKERS), dropouts: numberOrNull(row.DROPOUTS) })),
      entities: sites.map((row) => ({
        id: row.ENTITY_ID, name: row.ENTITY_NAME, region: row.REGION, category: row.CATEGORY, tier: row.RISK_TIER,
        pickups: numberOrNull(row.PICKUP_COUNT), opened: numberOrNull(row.ACCOUNTS_OPENED), blockers: numberOrNull(row.BLOCKER_COUNT), dropouts: numberOrNull(row.DROPOUT_COUNT),
        breaches: numberOrNull(row.SLA_BREACH_COUNT), dropoutRate: numberOrNull(row.BLOCKER_DROPOUT_PCT),
        payout: numberOrNull(row.PAYOUT_PHP_M), followup: numberOrNull(row.FOLLOWUP_COMPLETION_PCT), events: numberOrNull(row.EVENT_COUNT),
      })),
      followupRisk: sites.map((row) => ({
        name: row.ENTITY_NAME, completion: numberOrNull(row.FOLLOWUP_COMPLETION_PCT), dropouts: numberOrNull(row.DROPOUT_COUNT),
      })).filter((row) => row.completion !== null && row.dropouts !== null),
      sourceWatermark: watermark,
      rawWatermark: freshness[0]?.RAW_WATERMARK ?? null,
      stale: ageDays === null || ageDays > 2,
      pipelineBehind: freshness[0]?.RAW_WATERMARK !== watermark,
      requestedAt: new Date().toISOString(),
      synthetic: true,
      risk: risk.map((row) => ({
        id: row.ENTITY_ID, scoredAsOf: row.SCORED_AS_OF,
        probability: numberOrNull(row.DROPOUT_PROB_7D), band: row.RISK_BAND,
      })),
      holdout: holdout[0] ? {
        n: numberOrNull(holdout[0].N), baseRate: numberOrNull(holdout[0].BASE_RATE),
        precision: numberOrNull(holdout[0].PRECISION_AT_50), recall: numberOrNull(holdout[0].RECALL_AT_50),
      } : null,
      forecast: forecast.map((row) => ({
        period: row.PERIOD, value: numberOrNull(row.BLOCKER_COUNT),
        lower: numberOrNull(row.LOWER_BOUND), upper: numberOrNull(row.UPPER_BOUND),
      })),
      modelStatus: holdout[0] ? 'holdout_evaluated' : 'missing',
      live: live.map((row) => ({
        id: row.SITE_ID, eventTs: row.EVENT_TS, amount: numberOrNull(row.AMOUNT_PHP),
        onboardMin: numberOrNull(row.ONBOARD_MINUTES), status: row.STATUS, loadedAt: row.LOADED_AT,
      })),
      liveSummary: {
        n: numberOrNull(liveSummary[0]?.N), blockers: numberOrNull(liveSummary[0]?.BLOCKERS),
        lastLoaded: liveSummary[0]?.LAST_LOADED ?? null, medianLagSeconds: numberOrNull(liveSummary[0]?.MEDIAN_LAG_S),
      },
      anomalies: anomalies.map((row) => ({
        id: row.ENTITY_ID, date: row.EVENT_DATE, errorRate: numberOrNull(row.EKYC_ERROR),
        expected: numberOrNull(row.EXPECTED), upper: numberOrNull(row.UPPER_BOUND),
      })),
      alerts: alerts.map((row) => ({
        id: row.SITE_ID, eventTs: row.EVENT_TS, amount: numberOrNull(row.AMOUNT_PHP),
        onboardMin: numberOrNull(row.ONBOARD_MINUTES), hint: row.SOP_HINT,
      })),
    }, { headers: { 'Cache-Control': 'no-store' } });
  } catch {
    return NextResponse.json({ error: 'Site data is unavailable. Verify the core deployment and application role.' },
      { status: 503, headers: { 'Cache-Control': 'no-store' } });
  }
}
