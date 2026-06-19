import fs from 'fs';
import path from 'path';
import https from 'https';
import { pipeline } from 'stream/promises';
import { Writable, Readable } from 'stream';
import { Reader, CityResponse, AsnResponse } from 'mmdb-lib';
import { Client } from 'pg';
import { from as copyFrom } from 'pg-copy-streams';

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

const MMDB_URLS: Record<string, string> = {
  city: 'https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-City.mmdb',
  asn: 'https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-ASN.mmdb',
};

const DATA_DIR = process.env.GEOLITE_DATA_DIR || path.join(__dirname, '..', '.data');

// ---------------------------------------------------------------------------
// Download helpers
// ---------------------------------------------------------------------------

function followRedirects(url: string, maxRedirects = 5): Promise<NodeJS.ReadableStream> {
  return new Promise((resolve, reject) => {
    if (maxRedirects <= 0) return reject(new Error('Too many redirects'));
    const mod = url.startsWith('https') ? https : require('http');
    mod.get(url, (res: any) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        resolve(followRedirects(res.headers.location, maxRedirects - 1));
      } else if (res.statusCode === 200) {
        resolve(res);
      } else {
        reject(new Error(`HTTP ${res.statusCode} for ${url}`));
      }
    }).on('error', reject);
  });
}

async function downloadFile(url: string, dest: string): Promise<void> {
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  const stream = await followRedirects(url);
  await pipeline(stream as any, fs.createWriteStream(dest));
}

async function ensureMmdb(name: string): Promise<string> {
  const dest = path.join(DATA_DIR, `GeoLite2-${name === 'city' ? 'City' : 'ASN'}.mmdb`);
  if (!fs.existsSync(dest)) {
    const url = MMDB_URLS[name];
    console.log(`Downloading ${name} database from ${url} ...`);
    await downloadFile(url, dest);
    console.log(`Saved to ${dest}`);
  } else {
    console.log(`Using cached ${dest}`);
  }
  return dest;
}

// ---------------------------------------------------------------------------
// MMDB iteration
//
// The MMDB format is a binary search trie. The `maxmind` / `mmdb-lib` package
// only supports single-IP lookups. To extract ALL network→record pairs we walk
// the IPv4 (and optionally IPv6) address space, using the prefix length
// returned by `getWithPrefixLength` to skip entire CIDR blocks.
//
// For GeoLite2-City this yields ~4M records; each lookup is O(32) bit
// comparisons so the full scan takes a few seconds.
// ---------------------------------------------------------------------------

interface NetworkRecord<T> {
  network: string; // CIDR notation
  data: T;
}

function ipv4ToString(num: number): string {
  return [
    (num >>> 24) & 0xff,
    (num >>> 16) & 0xff,
    (num >>> 8) & 0xff,
    num & 0xff,
  ].join('.');
}

function* iterateIPv4<T>(reader: Reader<T>): Generator<NetworkRecord<T>> {
  let ip = 0; // 0.0.0.0 as uint32
  const max = 0x100000000; // 2^32

  while (ip < max) {
    const ipStr = ipv4ToString(ip >>> 0);
    const [data, prefixLen] = reader.getWithPrefixLength(ipStr);

    const blockBits = 32 - prefixLen;
    const blockSize = 1 << blockBits;

    if (data !== null) {
      // Compute the actual network address (mask off host bits)
      const networkAddr = (ip >>> blockBits) << blockBits;
      const networkStr = ipv4ToString(networkAddr >>> 0);
      yield { network: `${networkStr}/${prefixLen}`, data };
    }

    // Advance past this block
    const networkStart = ((ip >>> blockBits) << blockBits) >>> 0;
    ip = (networkStart + blockSize) >>> 0;
    if (ip === 0) break; // wrapped around
  }
}

function ipv6ToString(hi: bigint, lo: bigint): string {
  const parts: string[] = [];
  const full = (hi << 64n) | lo;
  for (let i = 7; i >= 0; i--) {
    parts.push(((full >> (BigInt(i) * 16n)) & 0xffffn).toString(16));
  }
  // Minimal compression: collapse longest run of 0 groups
  let bestStart = -1, bestLen = 0, curStart = -1, curLen = 0;
  for (let i = 0; i < 8; i++) {
    if (parts[i] === '0') {
      if (curStart === -1) curStart = i;
      curLen++;
      if (curLen > bestLen) { bestStart = curStart; bestLen = curLen; }
    } else {
      curStart = -1; curLen = 0;
    }
  }
  if (bestLen >= 2) {
    const before = parts.slice(0, bestStart).join(':');
    const after = parts.slice(bestStart + bestLen).join(':');
    return `${before}::${after}`;
  }
  return parts.join(':');
}

function* iterateIPv6<T>(reader: Reader<T>): Generator<NetworkRecord<T>> {
  let hi = 0n;
  let lo = 0n;
  const maxHi = 1n << 64n;

  while (hi < maxHi) {
    const ipStr = ipv6ToString(hi, lo);
    const [data, prefixLen] = reader.getWithPrefixLength(ipStr);

    const blockBits = 128 - prefixLen;

    if (data !== null) {
      // Compute network address
      const full = (hi << 64n) | lo;
      const mask = blockBits >= 128 ? 0n : ((1n << 128n) - 1n) << BigInt(blockBits);
      const networkFull = full & mask;
      const netHi = networkFull >> 64n;
      const netLo = networkFull & ((1n << 64n) - 1n);
      yield { network: `${ipv6ToString(netHi, netLo)}/${prefixLen}`, data };
    }

    // Advance past this block
    const full = (hi << 64n) | lo;
    const blockSize = 1n << BigInt(blockBits);
    const blockMask = blockBits >= 128 ? 0n : ((1n << 128n) - 1n) << BigInt(blockBits);
    const nextFull = (full & blockMask) + blockSize;
    if (nextFull >= (1n << 128n)) break;
    hi = nextFull >> 64n;
    lo = nextFull & ((1n << 64n) - 1n);
  }
}

// ---------------------------------------------------------------------------
// CSV generation helpers
// ---------------------------------------------------------------------------

function escapeCSV(val: unknown): string {
  if (val === null || val === undefined || val === '') return '';
  const s = String(val);
  if (s.includes(',') || s.includes('"') || s.includes('\n')) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

// ---------------------------------------------------------------------------
// Loaders
// ---------------------------------------------------------------------------

async function loadNetworks(client: Client, reader: Reader<CityResponse>): Promise<number> {
  console.log('Loading network blocks (IPv4) ...');
  let count = 0;

  const copyStream = client.query(
    copyFrom(`COPY geolite.network (
      network, geoname_id, registered_country_geoname_id,
      represented_country_geoname_id, is_anonymous_proxy, is_satellite_provider,
      postal_code, latitude, longitude, accuracy_radius, is_anycast
    ) FROM STDIN WITH (FORMAT csv)`)
  );

  const readable = new Readable({ read() {} });
  const pipelinePromise = pipeline(readable, copyStream);

  for (const { network, data } of iterateIPv4(reader)) {
    const row = [
      network,
      data.city?.geoname_id ?? data.country?.geoname_id ?? '',
      data.registered_country?.geoname_id ?? '',
      data.represented_country?.geoname_id ?? '',
      data.traits?.is_anonymous_proxy ?? false,
      data.traits?.is_satellite_provider ?? false,
      data.postal?.code ?? '',
      data.location?.latitude ?? '',
      data.location?.longitude ?? '',
      data.location?.accuracy_radius ?? '',
      false, // is_anycast not in mmdb
    ].map(escapeCSV).join(',');

    if (!readable.push(row + '\n')) {
      await new Promise<void>(resolve => readable.once('drain', resolve));
    }
    count++;
    if (count % 500000 === 0) console.log(`  ${count} network blocks ...`);
  }

  readable.push(null);
  await pipelinePromise;
  console.log(`  Loaded ${count} IPv4 network blocks`);
  return count;
}

async function loadNetworksIPv6(client: Client, reader: Reader<CityResponse>): Promise<number> {
  console.log('Loading network blocks (IPv6) ...');
  let count = 0;

  const copyStream = client.query(
    copyFrom(`COPY geolite.network (
      network, geoname_id, registered_country_geoname_id,
      represented_country_geoname_id, is_anonymous_proxy, is_satellite_provider,
      postal_code, latitude, longitude, accuracy_radius, is_anycast
    ) FROM STDIN WITH (FORMAT csv)`)
  );

  const readable = new Readable({ read() {} });
  const pipelinePromise = pipeline(readable, copyStream);

  for (const { network, data } of iterateIPv6(reader)) {
    const row = [
      network,
      data.city?.geoname_id ?? data.country?.geoname_id ?? '',
      data.registered_country?.geoname_id ?? '',
      data.represented_country?.geoname_id ?? '',
      data.traits?.is_anonymous_proxy ?? false,
      data.traits?.is_satellite_provider ?? false,
      data.postal?.code ?? '',
      data.location?.latitude ?? '',
      data.location?.longitude ?? '',
      data.location?.accuracy_radius ?? '',
      false,
    ].map(escapeCSV).join(',');

    if (!readable.push(row + '\n')) {
      await new Promise<void>(resolve => readable.once('drain', resolve));
    }
    count++;
    if (count % 500000 === 0) console.log(`  ${count} IPv6 network blocks ...`);
  }

  readable.push(null);
  await pipelinePromise;
  console.log(`  Loaded ${count} IPv6 network blocks`);
  return count;
}

async function loadLocations(client: Client, reader: Reader<CityResponse>): Promise<number> {
  console.log('Extracting unique locations ...');

  // Collect unique locations from the city reader by scanning IPv4
  const locations = new Map<number, CityResponse>();
  for (const { data } of iterateIPv4(reader)) {
    const geonameId = data.city?.geoname_id ?? data.country?.geoname_id;
    if (geonameId && !locations.has(geonameId)) {
      locations.set(geonameId, data);
    }
  }

  console.log(`  Found ${locations.size} unique locations, loading ...`);

  const copyStream = client.query(
    copyFrom(`COPY geolite.location (
      geoname_id, locale_code, continent_code, continent_name,
      country_iso_code, country_name,
      subdivision_1_iso_code, subdivision_1_name,
      subdivision_2_iso_code, subdivision_2_name,
      city_name, metro_code, time_zone, is_in_european_union
    ) FROM STDIN WITH (FORMAT csv)`)
  );

  const readable = new Readable({ read() {} });
  const pipelinePromise = pipeline(readable, copyStream);

  let count = 0;
  for (const [geonameId, data] of locations) {
    const subdivisions = data.subdivisions ?? [];
    const row = [
      geonameId,
      'en',
      data.continent?.code ?? '',
      data.continent?.names?.en ?? '',
      data.country?.iso_code ?? '',
      data.country?.names?.en ?? '',
      subdivisions[0]?.iso_code ?? '',
      subdivisions[0]?.names?.en ?? '',
      subdivisions[1]?.iso_code ?? '',
      subdivisions[1]?.names?.en ?? '',
      data.city?.names?.en ?? '',
      '', // metro_code not in mmdb
      data.location?.time_zone ?? '',
      data.country?.is_in_european_union ?? false,
    ].map(escapeCSV).join(',');

    readable.push(row + '\n');
    count++;
  }

  readable.push(null);
  await pipelinePromise;
  console.log(`  Loaded ${count} locations`);
  return count;
}

async function loadASN(client: Client, reader: Reader<AsnResponse>): Promise<number> {
  console.log('Loading ASN blocks (IPv4) ...');
  let count = 0;

  const copyStream = client.query(
    copyFrom(`COPY geolite.asn (
      network, autonomous_system_number, autonomous_system_organization
    ) FROM STDIN WITH (FORMAT csv)`)
  );

  const readable = new Readable({ read() {} });
  const pipelinePromise = pipeline(readable, copyStream);

  for (const { network, data } of iterateIPv4(reader)) {
    const row = [
      network,
      data.autonomous_system_number ?? 0,
      data.autonomous_system_organization ?? '',
    ].map(escapeCSV).join(',');

    if (!readable.push(row + '\n')) {
      await new Promise<void>(resolve => readable.once('drain', resolve));
    }
    count++;
    if (count % 500000 === 0) console.log(`  ${count} ASN blocks ...`);
  }

  readable.push(null);
  await pipelinePromise;
  console.log(`  Loaded ${count} IPv4 ASN blocks`);
  return count;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

export interface LoaderOptions {
  databaseUrl?: string;
  dataDir?: string;
  skipDownload?: boolean;
  ipv6?: boolean;
}

export async function loadGeoLite(opts: LoaderOptions = {}): Promise<void> {
  const databaseUrl = opts.databaseUrl || process.env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error('DATABASE_URL environment variable is required');
  }

  // 1. Download mmdb files
  if (!opts.skipDownload) {
    await ensureMmdb('city');
    await ensureMmdb('asn');
  }

  // 2. Open readers
  const cityPath = path.join(
    opts.dataDir || DATA_DIR,
    'GeoLite2-City.mmdb'
  );
  const asnPath = path.join(
    opts.dataDir || DATA_DIR,
    'GeoLite2-ASN.mmdb'
  );

  console.log('Opening MMDB databases ...');
  const cityBuf = fs.readFileSync(cityPath);
  const asnBuf = fs.readFileSync(asnPath);
  const cityReader = new Reader<CityResponse>(cityBuf);
  const asnReader = new Reader<AsnResponse>(asnBuf);

  // 3. Connect to PostgreSQL
  const client = new Client({ connectionString: databaseUrl });
  await client.connect();

  try {
    console.log('Truncating existing data ...');
    await client.query('BEGIN');
    await client.query('TRUNCATE geolite.network, geolite.location, geolite.asn, geolite.data_version');
    await client.query('COMMIT');

    // Load in order: locations first, then networks, then ASN
    await loadLocations(client, cityReader);
    await loadNetworks(client, cityReader);
    if (opts.ipv6) {
      await loadNetworksIPv6(client, cityReader);
    }
    await loadASN(client, asnReader);

    // Record version (id auto-generated via uuidv7)
    const version = new Date().toISOString().slice(0, 10);
    await client.query(
      `INSERT INTO geolite.data_version (version, loaded_at, source_url)
       VALUES ($1, now(), $2)`,
      [version, MMDB_URLS.city]
    );

    console.log('GeoLite2 data loaded successfully!');
  } finally {
    await client.end();
  }
}

// CLI entry point
if (require.main === module) {
  const args = process.argv.slice(2);
  const ipv6 = args.includes('--ipv6');

  loadGeoLite({ ipv6 }).catch((err) => {
    console.error('Error:', err.message);
    process.exit(1);
  });
}
