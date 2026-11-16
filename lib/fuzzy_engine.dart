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
export 'src/sugeno.dart';
export 'src/model_codec.dart';
export 'src/diagnostics.dart';
export 'src/tsukamoto.dart';
export 'src/fis_importer.dart';
export 'src/fis_exporter.dart';
export 'src/fcl.dart';
export 'src/fcl_exporter.dart';
