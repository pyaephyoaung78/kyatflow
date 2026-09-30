import 'package:flutter_test/flutter_test.dart';
import 'package:kyatflow/features/transactions/presentation/utils/amount_expression_evaluator.dart';

void main() {
  const evaluator = AmountExpressionEvaluator();

  test('evaluates operators with multiplication and division precedence', () {
    expect(evaluator.evaluate('2+3×4'), 14);
    expect(evaluator.evaluate('20÷4+3×2'), 11);
    expect(evaluator.evaluate('10-3-2'), 5);
  });

  test('rounds the submitted monetary value to two decimal places', () {
    expect(evaluator.evaluateMoney('10÷3'), 3.33);
    expect(evaluator.evaluateMoney('0.1+0.2'), 0.3);
  });

  test('rejects incomplete, malformed, and unsafe expressions', () {
    expect(() => evaluator.evaluate(''), throwsFormatException);
    expect(() => evaluator.evaluate('10+'), throwsFormatException);
    expect(() => evaluator.evaluate('10÷0'), throwsFormatException);
    expect(() => evaluator.evaluate('1..2'), throwsFormatException);
    expect(() => evaluator.evaluate('1(2)'), throwsFormatException);
  });
}
