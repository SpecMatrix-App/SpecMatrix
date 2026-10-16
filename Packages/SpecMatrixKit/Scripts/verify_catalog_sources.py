#!/usr/bin/env python3
"""Checks DeviceCatalog.json against the sources it cites.

For every entry and every field group (identifiers, marketingName, releaseDate, chip, display):
  * each recorded value must appear in at least one source attributed to that group;
  * each attributed source must confirm at least one value of the group (no decorative citations);
  * each hardware identifier must be confirmed by sources from at least two publishers.

Web sources are fetched with curl (cached under --cache). Xcode Simulator sources are read from
the locally installed device type profiles; their `representedModelIdentifiers` must equal the
entry's identifiers exactly, so a known variant cannot be silently left out.

This is a development tool: it makes network requests and is not part of the app or of CI.
It complements, and does not replace, the package's decoder tests.

Usage:
  python3 Packages/SpecMatrixKit/Scripts/verify_catalog_sources.py [--cache DIR] [--offline] [--only ID ...]
"""
import argparse
import hashlib
import html
import json
import os
import plistlib
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_CATALOG = os.path.join(HERE, '..', 'Sources', 'SpecMatrixCore', 'Resources', 'DeviceCatalog.json')
PROFILES = '/Library/Developer/CoreSimulator/Profiles/DeviceTypes'
WORDS = {1: 'one', 2: 'two', 3: 'three', 4: 'four', 5: 'five', 6: 'six', 7: 'seven', 8: 'eight', 9: 'nine',
         10: 'ten', 12: 'twelve', 16: 'sixteen'}
MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October',
          'November', 'December']


def normalize(text):
    text = re.sub(r'<(script|style)[^>]*>.*?</\1>', ' ', text, flags=re.S)
    text = html.unescape(re.sub(r'<[^>]+>', ' ', text))
    text = text.replace('­', '')  # soft hyphens, as in "perform­ance"
    for dash in '‐‑‒–—':
        text = text.replace(dash, '-')
    return re.sub(r'[\s   ]+', ' ', text)


def fetch(url, cache, offline, identifiers=()):
    path = os.path.join(cache, hashlib.sha256(url.encode()).hexdigest()[:24] + '.html')
    if not os.path.exists(path):
        if offline:
            raise RuntimeError(f'not cached: {url}')
        result = subprocess.run(['curl', '-sL', '--max-time', '60', '-A', 'Mozilla/5.0', '-o', path,
                                 '-w', '%{http_code}', url], capture_output=True, text=True)
        if result.stdout.strip() != '200':
            os.path.exists(path) and os.remove(path)
            raise RuntimeError(f'HTTP {result.stdout.strip() or "error"} for {url}')
    with open(path, encoding='utf-8', errors='ignore') as handle:
        raw = handle.read()
    title = re.search(r'<title[^>]*>(.*?)</title>', raw, re.S)
    # Apple's "Identify your Mac" pages describe many models, one <h2> section each. Only the sections
    # listing this entry's identifiers count, so a value stated for a different model is not accepted.
    if 'Model Identifier' in raw and identifiers:
        sections = [s for s in re.split(r'(?=<h2[ >])', raw)
                    if any(re.search(rf'(?<![\w,]){re.escape(i)}(?!\d)', normalize(s)) for i in identifiers)]
        return normalize(' '.join(sections)), '', True
    return normalize(raw), normalize(title.group(1)) if title else '', False


def number(n):
    return rf'(?:{n}|{WORDS[n]})' if n in WORDS else str(n)


def inches(value):
    return f'{value:g}'.replace('.', r'\.')


def claims(entry):
    """(group, description, regex or callable) for every recorded value."""
    out = [('marketingName', f'name "{entry["marketingName"]}"', None)]
    if 'releaseDate' in entry:
        year, month, day = (int(p) for p in entry['releaseDate'].split('-'))
        out.append(('releaseDate', f'release {entry["releaseDate"]}',
                    (year, rf'(?:in stores|availab\w*)[^.]*{MONTHS[month - 1]} {day}\b')))
    chip = entry.get('chip')
    if chip:
        name = re.escape(chip['name'])
        out.append(('chip', f'chip {chip["name"]}', rf'(?:\b(?:Apple )?{name} chip\b|\bChip: {name}\b)'))
        patterns = {
            # Apple writes "2 performance and 4 efficiency cores".
            'performanceCores': r'\b{n}[ -]performance\b',
            'efficiencyCores': r'\b{n}[ -]efficiency cores?\b',
            'gpuCores': r'\b{n}-core (?:GPU|graphics)\b',
            # Older releases: "The next-generation Neural Engine ... A new eight-core design allows it ...".
            'neuralEngineCores': r'(?:\b{n}-core (?:Apple )?Neural Engine\b|Neural Engine[^.]*\. A new {n}-core design\b)',
        }
        for key, pattern in patterns.items():
            if key in chip:
                out.append(('chip', f'{key} {chip[key]}', pattern.format(n=number(chip[key]))))
    display = entry.get('display')
    if display:
        if 'diagonalInches' in display:
            out.append(('display', f'diagonal {display["diagonalInches"]}', display['diagonalInches']))
        if 'pixelWidth' in display:
            out.append(('display', f'resolution {display["pixelWidth"]}x{display["pixelHeight"]}',
                        rf'\b{display["pixelHeight"]}-by-{display["pixelWidth"]}\b'))
        if 'pixelsPerInch' in display:
            out.append(('display', f'{display["pixelsPerInch"]} ppi',
                        rf'\b{display["pixelsPerInch"]} (?:ppi|pixels? per inch)'))
        if 'maximumRefreshRateHz' in display:
            out.append(('display', f'{display["maximumRefreshRateHz"]} Hz',
                        rf'\bto {display["maximumRefreshRateHz"]} ?Hz\b'))
    return out


def confirms(claim, text, title, url, scoped=False):
    group, _, pattern = claim
    if group == 'marketingName':
        key = lambda s: re.sub(r'[,\s]+', ' ', s).strip().lower()
        name = key(claim[1][6:-1])
        # A spec page names its model in the title; a scoped identification section names it in its heading.
        return key(title).startswith(name) or (scoped and name in key(text))
    if group == 'releaseDate':
        year, regex = pattern
        return f'/newsroom/{year}/' in url and re.search(regex, text) is not None
    if claim[1].startswith('diagonal'):
        return confirms_diagonal(pattern, text)
    return re.search(pattern, text) is not None


def confirms_diagonal(value, text):
    """The catalog records the diagonal measured as a rectangle. When the page states that figure
    for this device ("When measured as a standard rectangular shape, the screen is 6.12 inches"),
    the value must equal it; the rounded marketing size ("6.1-inch (diagonal)") is not accepted.
    Pages without such a statement describe rectangular screens, whose "(diagonal)" size is used."""
    d = inches(value)
    rectangle = r'measured (?:diagonally )?as a (?:standard )?rectang\w*(?: shape)?, '
    device_specific = re.findall(rectangle + r'the screen is ([\d.]+) inches', text)
    if device_specific:
        return any(float(figure) == value for figure in device_specific)
    if re.search(rectangle + r'[^.]*?\b' + d + r' inches', text):
        return True
    if re.search(rf'Actual diagonal screen size is {d} in\b', text):  # iMac: "24-inch" class, 23.5 in actual
        return True
    return re.search(rf'\b{d}-inch \(diagonal\)', text) is not None


def publisher(source):
    if 'url' in source:
        return '.'.join(source['url'].split('/')[2].lower().split('.')[-2:])
    return 'apple.com'


def verify(entry, cache, offline, installed_xcode):
    problems = []
    identifier_publishers = {i: set() for i in entry['identifiers']}
    entry_claims = claims(entry)
    confirmed = set()
    for source in entry['sources']:
        supports = set(source['supports'])
        if 'url' in source:
            try:
                text, title, scoped = fetch(source['url'], cache, offline, entry['identifiers'])
            except RuntimeError as error:
                problems.append(str(error))
                continue
            found = [i for i in entry['identifiers'] if re.search(rf'(?<![\w,]){re.escape(i)}(?!\d)', text)]
        else:
            if source['xcodeVersion'] != installed_xcode:
                problems.append(f'Xcode {source["xcodeVersion"]} cited, {installed_xcode or "none"} installed; profile not checked')
                continue
            path = os.path.join(PROFILES, source['xcodeSimulatorDeviceType'] + '.simdevicetype',
                                'Contents', 'Resources', 'profile.plist')
            try:
                with open(path, 'rb') as handle:
                    represented = set(plistlib.load(handle).get('representedModelIdentifiers', []))
            except OSError:
                problems.append(f'Simulator profile not found: {path}')
                continue
            if represented != set(entry['identifiers']):
                problems.append(f'{source["xcodeSimulatorDeviceType"]} represents {sorted(represented)}, '
                                f'entry has {sorted(entry["identifiers"])}')
            found = [i for i in entry['identifiers'] if i in represented]
            text = title = ''
            scoped = False
        if 'identifiers' in supports:
            if not found:
                problems.append(f'{source["title"]}: lists none of the identifiers')
            for identifier in found:
                identifier_publishers[identifier].add(publisher(source))
        for group in supports - {'identifiers'}:
            hits = [c for c in entry_claims if c[0] == group and confirms(c, text, title, source.get('url', ''), scoped)]
            if not hits:
                problems.append(f'{source["title"]}: confirms nothing for {group}')
            confirmed.update(c[1] for c in hits)
    for claim in entry_claims:
        if claim[1] not in confirmed:
            problems.append(f'{claim[1]} not confirmed by any {claim[0]} source')
    for identifier, publishers in identifier_publishers.items():
        if len(publishers) < 2:
            problems.append(f'{identifier} confirmed by {len(publishers)} publisher(s): {sorted(publishers)}')
    return problems


def installed_xcode_version():
    try:
        out = subprocess.run(['xcodebuild', '-version'], capture_output=True, text=True).stdout.split('\n')
        version = out[0].replace('Xcode ', '').strip()
        build = out[1].replace('Build version ', '').strip()
        return f'{version} ({build})'
    except (OSError, IndexError):
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--catalog', default=DEFAULT_CATALOG)
    parser.add_argument('--cache', default=os.path.join(os.environ.get('TMPDIR', '/tmp'), 'specmatrix-source-cache'))
    parser.add_argument('--offline', action='store_true', help='use only cached pages')
    parser.add_argument('--only', nargs='*', help='entry IDs to check')
    args = parser.parse_args()
    os.makedirs(args.cache, exist_ok=True)
    with open(args.catalog, encoding='utf-8') as handle:
        catalog = json.load(handle)
    xcode = installed_xcode_version()
    failures = 0
    entries = [e for e in catalog['entries'] if not args.only or e['id'] in args.only]
    for entry in entries:
        problems = verify(entry, args.cache, args.offline, xcode)
        status = 'ok' if not problems else 'FAIL'
        print(f'{status:4} {entry["id"]}')
        for problem in problems:
            print(f'       - {problem}')
        failures += bool(problems)
    print(f'\n{len(entries) - failures}/{len(entries)} entries verified against their sources '
          f'(catalog {catalog["catalogVersion"]}, Xcode {xcode}).')
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
