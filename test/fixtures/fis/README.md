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
