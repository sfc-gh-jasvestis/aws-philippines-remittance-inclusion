"""Publish simulated remittance pickup events to Amazon Data Firehose (stream <prefix>-pickups).

Firehose batches the records into S3 (pickups/); Snowpipe loads them into RAW.LIVE_PICKUPS.
Site IDs come from RAW.SITES (RS-0000..RS-0039). Values are seeded random.
"""
import argparse
import json
import random
import time
from datetime import datetime, timezone


def make_event(rng):
    blocker = rng.random() < 0.1
    return {'site_id': f'RS-{rng.randint(0, 39):04d}',
            'event_ts': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3],
            'amount_php': round((14500 if blocker else 6800) * rng.lognormvariate(0, 0.5), 2),
            'onboard_minutes': round((38 if blocker else 12) * rng.lognormvariate(0, 0.4), 1),
            'status': 'BLOCKER' if blocker else 'OK',
            'sent_ms': int(time.time() * 1000)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--region', default='us-west-2')
    ap.add_argument('--prefix', default='ph-remittance-inclusion')
    ap.add_argument('--count', type=int, default=40)
    ap.add_argument('--seed', type=int)
    args = ap.parse_args()
    import boto3
    firehose = boto3.client('firehose', region_name=args.region)
    stream = f'{args.prefix}-pickups'
    rng = random.Random(args.seed)
    records = [{'Data': (json.dumps(make_event(rng)) + '\n').encode()} for _ in range(args.count)]
    for start in range(0, len(records), 500):
        out = firehose.put_record_batch(DeliveryStreamName=stream, Records=records[start:start + 500])
        if out['FailedPutCount']:
            raise RuntimeError(f"{out['FailedPutCount']} records were rejected by Firehose")
    print(f'published {args.count} remittance pickup events to Firehose stream {stream}; S3 delivery buffers up to 60 s')


if __name__ == '__main__':
    main()
