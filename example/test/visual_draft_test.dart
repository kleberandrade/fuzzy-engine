import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzy_engine_example/lab_model.dart';
import 'package:fuzzy_engine_example/visual_draft.dart';

void main() {
  test('edits are isolated and changing a consequent changes the decision', () {
    final original = comparisonModels()[1];
    final draft = VisualDraft(original);
    draft.rules[1]['consequent'] = {'type': 'constant', 'value': 60};
    expect(draft.validate().evaluate({'demand': 50}).outputs['power'], 40);
    expect(original.evaluate({'demand': 50}).outputs['power'], 50);
  });
  test('renaming a term preserves condition and consequent references', () {
    final draft = VisualDraft(comparisonModels().first);
    draft.renameTerm(true, 0, 'low', 'gentle');
    draft.renameTerm(false, 0, 'low', 'slow');
    expect(draft.validate().evaluate({'demand': 25}).outputs['power'],
        comparisonModels().first.evaluate({'demand': 25}).outputs['power']);
    expect((draft.rules.first['when'] as Map)['term'], 'gentle');
    expect(draft.rules.first['term'], 'slow');
  });
  test('all supported membership defaults validate; Tsukamoto stays monotonic',
      () {
    for (final type in VisualDraft.shapes.keys) {
      final draft = VisualDraft(comparisonModels().first);
      draft.terms(true, 0)['low'] = VisualDraft.membership(type, 0, 100);
      expect(draft.validate().evaluate({'demand': 25}).outputs['power'],
          isNotNull);
    }
    expect(VisualDraft.monotonicShapes, ['ramp', 'sShape', 'zShape']);
  });
  test('invalid numbers and referenced deletions block application', () {
    final draft = VisualDraft(comparisonModels().first);
    draft.inputs.first['max'] = 'not a number';
    expect(draft.validate, throwsFormatException);
    draft.inputs.first['max'] = 100;
    draft.terms(true, 0).remove('low');
    expect(draft.validate, throwsFormatException);
  });
  test('adding rules, nested operators and hedges survives JSON interchange',
      () {
    final draft = VisualDraft(comparisonModels()[2]);
    draft.addRule();
    draft.rules.last['when'] = {
      'type': 'and',
      'left': {
        'type': 'hedge',
        'modifier': 'very',
        'operand': draft.defaultCondition()
      },
      'right': {
        'type': 'not',
        'operand': {'type': 'term', 'variable': 'demand', 'term': 'high'}
      }
    };
    final model = draft.validate();
    expect(LabModel.import(model.export()).evaluate({'demand': 25}).outputs,
        model.evaluate({'demand': 25}).outputs);
  });
}
