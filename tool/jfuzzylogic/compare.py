"""Compare original/exported FCL with the real, pinned jFuzzyLogic runtime.
Usage: python tool/jfuzzylogic/compare.py cases.json java classpath [reference.json]
Only Python standard-library code is needed. No external Java source is vendored.
"""
import hashlib
import json
import math
import pathlib
import subprocess
import sys
import tempfile

COMMIT = '1f421d1b176b39cd7d08fa8f4d712d733abf1116'


def close(a, b, tolerance=1e-10):
    assert math.isfinite(a) and math.isfinite(b) and abs(a-b) <= tolerance, (a, b, tolerance)


def main():
    cases = json.loads(pathlib.Path(sys.argv[1]).read_text())
    java, classpath = sys.argv[2:4]
    records = []
    largest_raw_difference = 0.0
    largest_mapped_difference = 0.0
    comparisons = 0
    default_policy_differences = 0
    with tempfile.TemporaryDirectory(prefix='fcl-external-') as directory:
        path = pathlib.Path(directory) / 'model.fcl'
        for case in cases:
            for key in ['source', 'exportedSource']:
                path.write_text(case[key])
                process = subprocess.run([java, '-Djava.awt.headless=true', '-cp', classpath,
                    'FclProbe', str(path), str(case['inputs']['temperature']),
                    str(case['inputs']['humidity']), str(case['intervals'])],
                    check=True, capture_output=True, text=True)
                external = json.loads(process.stdout)
                for variable, terms in case['memberships'].items():
                    for term, value in terms.items():
                        close(value, external['memberships'][variable][term], 1e-12)
                assert len(case['strengths']) == len(external['strengths'])
                for a, b in zip(case['strengths'], external['strengths']):
                    close(a, b, 1e-12)
                curve = external['degrees']
                assert len(curve) == case['intervals']
                for a, b in zip(case['degrees'][:-1], curve):
                    close(a, b)
                close(case['degrees'][-1], external['endpointDegree'])
                low, high = external['min'], external['max']
                step = external['step']
                close(step, (high-low)/len(curve))
                area_sum = math.fsum(curve)
                moment_sum = math.fsum((low+i*step)*y for i, y in enumerate(curve))
                external_default = area_sum == 0
                if external_default:
                    close(external['rawValue'], case['defaultValue'])
                else:
                    # jFuzzyLogic's COG is a left-endpoint sum, excluding max.
                    close(external['rawValue'], moment_sum/area_sum, 1e-9)
                # Correct even when only max has positive membership: the
                # external grid then uses DEFAULT while our grid has area.
                end = external['endpointDegree']
                trap_area = area_sum+(end-curve[0])/2
                trap_moment = moment_sum+(high*end-low*curve[0])/2
                mapped_default = trap_area == 0
                mapped = case['defaultValue'] if mapped_default else trap_moment/trap_area
                assert mapped_default == case['usedDefault']
                default_policy_differences += int(external_default != mapped_default)
                close(mapped, case['value'], 1e-9)
                largest_raw_difference = max(largest_raw_difference, abs(external['rawValue']-case['value']))
                largest_mapped_difference = max(largest_mapped_difference, abs(mapped-case['value']))
                comparisons += 1
                if key == 'source':
                    records.append({
                        'variant': case['variant'], 'source': case[key],
                        'sourceSha256': hashlib.sha256(case[key].encode()).hexdigest(),
                        'inputs': case['inputs'], 'intervals': case['intervals'],
                        'memberships': external['memberships'], 'strengths': external['strengths'],
                        'rawExternalValue': external['rawValue'], 'trapezoidalValue': mapped,
                        'externalUsedDefault': external_default,
                        'usedDefault': case['usedDefault'], 'tolerance': 1e-9,
                    })
    report = {'tool': 'jFuzzyLogic', 'commit': COMMIT, 'comparisons': comparisons,
              'maxRawCrispDifference': largest_raw_difference,
              'maxMappedCrispDifference': largest_mapped_difference, 'status': 'passed'}
    report['samplingDefaultDifferences'] = default_policy_differences
    if len(sys.argv) > 4:
        pathlib.Path(sys.argv[4]).write_text(json.dumps({'report': report, 'cases': records}, indent=2)+'\n')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
