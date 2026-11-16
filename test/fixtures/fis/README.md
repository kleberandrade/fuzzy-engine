# FIS analytical fixture

`ventilation.fis` is an original fixture authored for this project under its MIT
license. It was not exported by MATLAB or copied from a vendor example. Its
syntax follows the documented text FIS layout; independent vendor-generated
fixtures and cross-tool numeric comparisons remain pending.

At temperature=0.5, humidity=0.75, the first two antecedents are 0.25 and 0.75;
weights 0.8 and 0.4 produce strengths 0.2 and 0.3. The third rule ignores the
first input and has weight zero. With four integration intervals on [0,10],
max aggregation of clipped output shoulders gives [0.2,0.25,0.3,0.3,0.3].
Composite trapezoidal area is 2.75, moment is 14.6875, centroid is 235/44.
These values are analytical references for this sampling convention, not captured
MATLAB results. The Gaussian parameter test separately uses exp(-1/2).

The test suite also checks endpoints, overlap, no activation and a narrow output
missed by the selected sample grid. Equal method names do not guarantee equal
quadrature or output values across tools.

References:
- https://help.functionbay.com/2026/RecurDynHelp/Colink/Colink_ch06_s12_02.html
- https://www.mathworks.com/help/fuzzy/gaussmf.html
- https://la.mathworks.com/help/fuzzy/fuzzy.evalfis.evalfisoptions.html

## Recorded external references

`sugeno.fis` is also original MIT-licensed fixture data. It deliberately includes
an unused consequent and a linear function with asymmetric coefficients and an
intercept so parameter-order errors are observable.

`external-reference.json` was generated on 2026-11-16 with the unmodified official
scikit-fuzzy 0.5.0 wheel, NumPy 2.2.6, SciPy 1.15.3, packaging 25.0 and networkx
3.4.2, installed into a temporary test directory. Wheels were downloaded from
PyPI and checked against its SHA-256 metadata. No library source is vendored.
The file records 63 independent numerical cases, source hashes and tolerances;
original and exported sources passed 126 live comparisons. The maximum observed
crisp difference was 3.3333333480101146e-6. It is bounded by the known trapezoidal
versus exact piecewise-linear moment difference, documented in doc/fis.en.md.

Regenerate with tool/export_external_cases.dart and tool/compare_external.py.
The Python evaluator uses scikit-fuzzy for memberships/centroid and independent
NumPy arithmetic for Sugeno. It does not validate against MATLAB itself or claim
that an external tool exported our original FIS fixtures. Golden regression tests
are complemented by a live comparison job in CI.
