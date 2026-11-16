# Original FCL fixture

ventilation.fcl is original MIT-licensed project data, not a vendor export. It
represents the two active rules of the original FIS ventilation fixture; the FIS
fixture's extra zero-weight rule does not affect outputs. At [.5,.75] with four
output intervals, the expected trapezoidal centroid is 235/44. Nine endpoint and
overlap cases also compare memberships, activations and outputs against recorded
scikit-fuzzy data for the equivalent FIS model. This is numerical evidence, not
execution or certification of an external FCL parser. See doc/fcl.en.md.
