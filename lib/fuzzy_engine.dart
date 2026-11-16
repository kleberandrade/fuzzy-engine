/// Explainable fuzzy inference for Dart and Flutter.
library;

export 'src/membership.dart';
export 'src/model.dart';
export 'src/engine.dart';
export 'src/operators.dart'
    show
        TNorm,
        SNorm,
        FuzzyNegation,
        Minimum,
        Maximum,
        AlgebraicProduct,
        ProbabilisticSum,
        BoundedDifference,
        BoundedSum,
        StandardNegation,
        FuzzyOperators;
export 'src/defuzzification.dart';
export 'src/hedges.dart';
