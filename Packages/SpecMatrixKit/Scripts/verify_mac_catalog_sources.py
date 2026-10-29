#!/usr/bin/env python3
"""Checks MacCatalog.json (schema 2) against the sources it cites.

The Mac counterpart of verify_catalog_sources.py, whose fetching, caching and matching helpers it reuses.
For every entry:
  * marketingName, releaseDate and display values must appear in a source attributed to that group
    (display resolution is stored landscape, as Apple writes it: "2560-by-1664");
  * each hardware identifier must be confirmed by sources from at least two publishers;
  * each chip configuration must be stated by an apple.com source attributed to `chip`:
      - the chip has its own "Apple <chip> chip" section, or is named in a "<chip> with N-core CPU" option;
      - the CPU/GPU pair is the section's base configuration (its first CPU and first GPU, or any listed GPU
        when the section lists a single CPU), or an option such as "M2 with 8-core CPU and 10-core GPU";
      - recorded CPU clusters equal the section's "N-core CPU with a super/performance/efficiency cores"
        statement for that CPU, and the Neural Engine count is stated in the chip's section or option;
  * completeness: every CPU/GPU pair the page states for a recorded chip is recorded, and a cluster split
    or Neural Engine count the page states is not left out.

Like the iPhone/iPad verifier, this is a development tool: it makes network requests (cached under
--cache) and is not part of the app or of CI.

Usage:
  python3 Packages/SpecMatrixKit/Scripts/verify_mac_catalog_sources.py [--cache DIR] [--offline] [--only ID ...]
"""
import argparse
import copy
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import verify_catalog_sources as base  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_CATALOG = os.path.join(HERE, '..', 'Sources', 'SpecMatrixMacCatalog', 'Resources', 'MacCatalog.json')
SUPPORTED_SCHEMA = 2
CHIP = r'M\d+(?: Pro| Max| Ultra)?'
TIER = r'(\d+) (super|performance|efficiency) cores?'
# "Dual 16-core Neural Engine" (M6) is not a single core count.
NEURAL_ENGINE = r'(?<!Dual )\b(\d+)-core Neural Engine\b'
OPTION = rf'\b({CHIP}) with (\d+)-core CPU,? (?:and )?(\d+)-core GPU(?:,? and (\d+)-core Neural Engine)?'


def chip_sections(text):
    """{chip: [section]} for each "Apple <chip> chip" heading that states a CPU, up to the next heading."""
    heads = list(re.finditer(rf'\bApple ({CHIP}) chip\b', text))
    sections = {}
    for index, head in enumerate(heads):
        end = heads[index + 1].start() if index + 1 < len(heads) else len(text)
        section = text[head.start():min(end, head.end() + 1500)]
        if re.search(r'\d+-core CPU', section):
            sections.setdefault(head.group(1), []).append(section)
    return sections


def cpu_statements(section):
    """[(cpu, [(type, cores), ...])] in the order the section states them."""
    out = []
    for match in re.finditer(r'\b(\d+)-core CPU with (.*?)(?=, \d+-core CPU|\s\d+-core GPU|$)', section):
        tiers = [(kind, int(cores)) for cores, kind in re.findall(TIER, match.group(2))]
        out.append((int(match.group(1)), tiers))
    return out


def base_options(section):
    """The section's own GPU options, before any "Configurable to" list."""
    head = section.split('Configurable to')[0]
    return [int(n) for n in re.findall(r'\b(\d+)-core GPU\b', head)]


def stated(text):
    """Everything the page states per chip: CPU/GPU pairs, cluster splits and Neural Engine counts."""
    pairs, clusters, neural = {}, {}, {}
    for chip, sections in chip_sections(text).items():
        for section in sections:
            cpus, gpus = cpu_statements(section), base_options(section)
            if cpus and gpus:
                pairs.setdefault(chip, set()).add((cpus[0][0], gpus[0]))
                if len({cpu for cpu, _ in cpus}) == 1:
                    pairs[chip].update((cpus[0][0], gpu) for gpu in gpus)
            for cpu, tiers in cpus:
                if tiers:
                    clusters.setdefault((chip, cpu), set()).add(tuple(tiers))
            for count in re.findall(NEURAL_ENGINE, section):
                neural.setdefault(chip, set()).add(int(count))
    for chip, cpu, gpu, count in re.findall(OPTION, text):
        pairs.setdefault(chip, set()).add((int(cpu), int(gpu)))
        if count:
            neural.setdefault(chip, set()).add(int(count))
    return pairs, clusters, neural


def verify_configurations(entry, text):
    problems = []
    pairs, clusters, neural = stated(text)
    recorded = entry.get('configurations', [])
    for config in recorded:
        chip, cpu, gpu = config['chip'], config.get('cpuCores'), config.get('gpuCores')
        label = f'{chip} {cpu}-core CPU / {gpu}-core GPU'
        if chip not in pairs:
            problems.append(f'{label}: the page states no configuration of {chip}')
            continue
        if cpu is not None and gpu is not None and (cpu, gpu) not in pairs[chip]:
            problems.append(f'{label}: not stated (page states {sorted(pairs[chip])})')
        if 'cpuClusters' in config:
            tiers = tuple((c['type'], c['cores']) for c in config['cpuClusters'])
            if tiers not in clusters.get((chip, cpu), set()):
                problems.append(f'{label}: clusters {tiers} not stated (page: {sorted(clusters.get((chip, cpu), []))})')
        elif clusters.get((chip, cpu)):
            problems.append(f'{label}: the page states clusters {sorted(clusters[(chip, cpu)])} but none are recorded')
        if 'neuralEngineCores' in config:
            if config['neuralEngineCores'] not in neural.get(chip, set()):
                problems.append(f'{label}: {config["neuralEngineCores"]}-core Neural Engine not stated')
        elif len(neural.get(chip, set())) == 1:
            problems.append(f'{label}: the page states a {sorted(neural[chip])[0]}-core Neural Engine but none is recorded')
    for chip in {c['chip'] for c in recorded}:
        have = {(c.get('cpuCores'), c.get('gpuCores')) for c in recorded if c['chip'] == chip}
        for missing in sorted(pairs.get(chip, set()) - have):
            problems.append(f'{chip} {missing[0]}-core CPU / {missing[1]}-core GPU is stated but not recorded')
    return problems


def verify(entry, cache, offline):
    problems = []
    # The iPhone/iPad claims describe resolution as height-by-width (portrait storage); Mac entries are
    # landscape, so swap before reusing them. Chip claims are replaced by the configuration checks.
    legacy = copy.deepcopy(entry)
    legacy.pop('configurations', None)
    display = legacy.get('display', {})
    if 'pixelWidth' in display:
        display['pixelWidth'], display['pixelHeight'] = display['pixelHeight'], display['pixelWidth']
    entry_claims = base.claims(legacy)
    confirmed = set()
    identifier_publishers = {i: set() for i in entry['identifiers']}
    chip_checked = False
    for source in entry['sources']:
        supports = set(source['supports'])
        try:
            text, title, scoped = base.fetch(source['url'], cache, offline, entry['identifiers'])
        except RuntimeError as error:
            problems.append(str(error))
            continue
        if 'identifiers' in supports:
            found = [i for i in entry['identifiers'] if re.search(rf'(?<![\w,]){re.escape(i)}(?!\d)', text)]
            if not found:
                problems.append(f'{source["title"]}: lists none of the identifiers')
            for identifier in found:
                identifier_publishers[identifier].add(base.publisher(source))
        if 'chip' in supports and scoped:
            # An "Identify your Mac" section ties this entry's identifiers to a chip; it lists no configurations.
            for chip in sorted({c['chip'] for c in entry.get('configurations', [])}):
                if not re.search(rf'\b{re.escape(chip)}\b(?! Pro| Max| Ultra)', text):
                    problems.append(f'{source["title"]}: does not name {chip} for these identifiers')
        elif 'chip' in supports:
            chip_checked |= base.publisher(source) == 'apple.com'
            problems += [f'{source["title"]}: {p}' for p in verify_configurations(entry, text)]
        for group in supports - {'identifiers', 'chip'}:
            hits = [c for c in entry_claims if c[0] == group and base.confirms(c, text, title, source['url'], scoped)]
            if not hits:
                problems.append(f'{source["title"]}: confirms nothing for {group}')
            confirmed.update(c[1] for c in hits)
    for claim in entry_claims:
        if claim[1] not in confirmed:
            problems.append(f'{claim[1]} not confirmed by any {claim[0]} source')
    if entry.get('configurations') and not chip_checked:
        problems.append('configurations are not attributed to an apple.com source')
    for identifier, publishers in identifier_publishers.items():
        if len(publishers) < 2:
            problems.append(f'{identifier} confirmed by {len(publishers)} publisher(s): {sorted(publishers)}')
    return problems


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
    if catalog.get('schemaVersion') != SUPPORTED_SCHEMA:
        print(f'Unsupported schemaVersion {catalog.get("schemaVersion")}; this tool checks schema {SUPPORTED_SCHEMA}.')
        return 2
    failures = 0
    entries = [e for e in catalog['entries'] if not args.only or e['id'] in args.only]
    for entry in entries:
        problems = verify(entry, args.cache, args.offline)
        print(f'{"ok" if not problems else "FAIL":4} {entry["id"]} ({len(entry.get("configurations", []))} configurations)')
        for problem in problems:
            print(f'       - {problem}')
        failures += bool(problems)
    print(f'\n{len(entries) - failures}/{len(entries)} Mac entries verified against their sources '
          f'(catalog {catalog["catalogVersion"]}).')
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
