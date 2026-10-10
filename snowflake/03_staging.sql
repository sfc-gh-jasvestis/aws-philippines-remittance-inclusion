-- Validate the producer contract before building downstream objects.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

EXECUTE IMMEDIATE $$
DECLARE
  violations INTEGER;
  invalid_source EXCEPTION (-20001, 'Synthetic source failed grain or measure validation');
BEGIN
  SELECT COUNT(*) INTO :violations FROM (
    SELECT ENTITY_ID, EVENT_DATE
    FROM RAW.SITE_DAILY
    GROUP BY ENTITY_ID, EVENT_DATE HAVING COUNT(*) <> 1
    UNION ALL
    SELECT observation.ENTITY_ID, observation.EVENT_DATE
    FROM RAW.SITE_DAILY observation
    LEFT JOIN RAW.SITES site ON site.ID = observation.ENTITY_ID
    WHERE site.ID IS NULL OR observation.PICKUP_COUNT < 0
       OR observation.PAYOUT_PHP < 0
       OR observation.DROPOUT_COUNT < 0 OR observation.DROPOUT_COUNT > observation.BLOCKER_COUNT
       OR observation.BLOCKER_COUNT > observation.PICKUP_COUNT
       OR observation.ACCOUNTS_OPENED < 0 OR observation.ACCOUNTS_OPENED > observation.PICKUP_COUNT
       OR observation.SLA_BREACHED > observation.DROPOUT_COUNT
       OR observation.FOLLOWUP_COMPLETED > observation.FOLLOWUP_DUE
  );
  IF (violations > 0) THEN
    RAISE invalid_source;
  END IF;
END;
$$;
