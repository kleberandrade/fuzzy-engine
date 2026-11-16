"""Independent FIS evaluation with scikit-fuzzy, NumPy and SciPy installed.

Usage: dart run tool/export_external_cases.dart > /tmp/fis-cases.json
       python tool/compare_external.py /tmp/fis-cases.json
This evaluator does not import or translate Dart membership/inference code.
"""
import json
import hashlib
import re
import sys
import numpy as np
import skfuzzy as fuzz


def sections(source):
    result = {}
    current = None
    for line in source.splitlines():
        line = line.strip()
        if not line or line.startswith('%'):
            continue
        if line.startswith('['):
            current = line[1:-1]
            result[current] = [] if current == 'Rules' else {}
        elif current == 'Rules':
            result[current].append(line)
        else:
            key, value = line.split('=', 1)
            result[current][key.strip()] = value.strip()
    return result


def mf(definition):
    match = re.fullmatch(r"'([^']+)':'([^']+)',\[([^\]]+)\]", definition)
    if not match:
        raise ValueError(definition)
    name, kind, params = match.groups()
    return name, kind, np.array([float(p) for p in params.split()])


def degree(kind, params, values):
    if kind == 'trimf':
        return fuzz.trimf(values, params)
    if kind == 'trapmf':
        return fuzz.trapmf(values, params)
    if kind == 'gaussmf':
        return fuzz.gaussmf(values, params[1], params[0])
    raise ValueError(kind)


def evaluate(source, inputs, intervals):
    data = sections(source)
    system = data['System']
    variables = [data[f'Input{i+1}'] for i in range(int(system['NumInputs']))]
    memberships = {}
    ordered = []
    for var in variables:
        name = var['Name'][1:-1]
        degrees = {}
        for i in range(int(var['NumMFs'])):
            label, kind, params = mf(var[f'MF{i+1}'])
            degrees[label] = float(degree(kind, params, np.array([inputs[name]]))[0])
        memberships[name] = degrees
        ordered.append(list(degrees.values()))
    output = data['Output1']
    terms = [mf(output[f'MF{i+1}']) for i in range(int(output['NumMFs']))]
    bounds = [float(v) for v in output['Range'][1:-1].split()]
    xs = np.linspace(*bounds, intervals+1)
    aggregate = np.zeros_like(xs)
    strengths, consequents = [], []
    for row in data['Rules']:
        match = re.fullmatch(r'(.+),\s*(\d+)\s*\(([^)]+)\)\s*:\s*([12])', row)
        indices, out, weight, connector = match.groups()
        active = []
        for i, index in enumerate(map(int, indices.split())):
            if index:
                value = ordered[i][abs(index)-1]
                active.append(1-value if index < 0 else value)
        if connector == '1':
            antecedent = min(active) if system['AndMethod'] == "'min'" else float(np.prod(active))
        else:
            antecedent = max(active) if system['OrMethod'] == "'max'" else 1-float(np.prod(1-np.array(active)))
        strength = antecedent*float(weight)
        strengths.append(strength)
        _, kind, params = terms[int(out)-1]
        if system['Type'] == "'mamdani'":
            curve = degree(kind, params, xs)
            implied = np.minimum(strength, curve) if system['ImpMethod'] == "'min'" else strength*curve
            aggregate = np.maximum(aggregate, implied)
        else:
            ordered_inputs = [inputs[var['Name'][1:-1]] for var in variables]
            z = params[0] if kind == 'constant' else float(np.dot(params[:-1], ordered_inputs)+params[-1])
            consequents.append(z)
    if system['Type'] == "'sugeno'":
        total = sum(strengths)
        value = None if not total else float(np.dot(strengths, consequents))
        if value is not None and system['DefuzzMethod'] == "'wtaver'":
            value /= total
        return memberships, strengths, value, None, 1e-12
    area = float(np.trapezoid(aggregate, xs))
    value = None if not area else float(fuzz.defuzz(xs, aggregate, 'centroid'))
    # scikit-fuzzy integrates the piecewise-linear moment exactly; Dart uses
    # trapezoidal moment quadrature. On a uniform grid the error telescopes:
    # |M_trap-M_exact| = h^2*|mu_last-mu_first|/6, with identical sampled area.
    tolerance = 1e-10 if not area else ((xs[1]-xs[0])**2*abs(aggregate[-1]-aggregate[0])/(6*area)+1e-10)
    return memberships, strengths, value, aggregate, tolerance


def main():
    cases = json.load(open(sys.argv[1], encoding='utf-8'))
    maximum_error = 0.0
    comparisons = 0
    references = []
    for case in cases:
        for key in ['source', 'exportedSource']:
            memberships, strengths, value, curve, tolerance = evaluate(
                case[key], case['inputs'], case.get('intervals', 1000))
            for variable, terms in memberships.items():
                for term, degree_value in terms.items():
                    np.testing.assert_allclose(degree_value, case['memberships'][variable][term], atol=1e-12, rtol=0)
            np.testing.assert_allclose(strengths, case['strengths'], atol=1e-12, rtol=0)
            if curve is not None:
                np.testing.assert_allclose(curve, case['degrees'], atol=1e-12, rtol=0)
            if value is None:
                assert case['value'] is None
            else:
                error = abs(value-case['value'])
                assert error <= tolerance, (case['family'], case['inputs'], error, tolerance)
                maximum_error = max(maximum_error, error)
            comparisons += 1
            if key == 'source':
                references.append({
                    'family': case['family'], 'variant': case['variant'],
                    'source': case[key],
                    'sourceSha256': hashlib.sha256(case[key].encode()).hexdigest(),
                    'inputs': case['inputs'], 'memberships': memberships,
                    'strengths': strengths, 'externalValue': value,
                    'crispTolerance': float(tolerance),
                    'intervals': case.get('intervals', 1000),
                })
    report = {'externalTool': 'scikit-fuzzy', 'version': fuzz.__version__,
                      'comparisons': comparisons, 'maxCrispDifference': maximum_error,
                      'status': 'passed'}
    if len(sys.argv) == 3:
        with open(sys.argv[2], 'w', encoding='utf-8') as target:
            json.dump({'report': report, 'cases': references}, target, indent=2)
            target.write('\n')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
