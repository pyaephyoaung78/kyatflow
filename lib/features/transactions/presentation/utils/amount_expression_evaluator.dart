class AmountExpressionEvaluator {
  const AmountExpressionEvaluator();

  static const operators = {'+', '-', '×', '÷'};

  double evaluate(String expression) {
    if (expression.isEmpty) {
      throw const FormatException('Enter an amount');
    }

    final numbers = <double>[];
    final parsedOperators = <String>[];
    final currentNumber = StringBuffer();

    for (final character in expression.split('')) {
      if (operators.contains(character)) {
        _pushNumber(currentNumber, numbers);
        parsedOperators.add(character);
      } else if (_isDigit(character) || character == '.') {
        currentNumber.write(character);
      } else {
        throw FormatException('Unsupported character: $character');
      }
    }
    _pushNumber(currentNumber, numbers);

    if (numbers.length != parsedOperators.length + 1) {
      throw const FormatException('Complete the calculation');
    }

    // Resolve multiplication and division first, retaining addition and
    // subtraction for a second left-to-right pass.
    final reducedNumbers = <double>[numbers.first];
    final reducedOperators = <String>[];
    for (var index = 0; index < parsedOperators.length; index++) {
      final operator = parsedOperators[index];
      final right = numbers[index + 1];
      if (operator == '×' || operator == '÷') {
        final left = reducedNumbers.removeLast();
        if (operator == '÷' && right == 0) {
          throw const FormatException('Cannot divide by zero');
        }
        reducedNumbers.add(operator == '×' ? left * right : left / right);
      } else {
        reducedOperators.add(operator);
        reducedNumbers.add(right);
      }
    }

    var total = reducedNumbers.first;
    for (var index = 0; index < reducedOperators.length; index++) {
      total = reducedOperators[index] == '+'
          ? total + reducedNumbers[index + 1]
          : total - reducedNumbers[index + 1];
    }
    if (!total.isFinite) {
      throw const FormatException('The result is too large');
    }
    return total;
  }

  /// Matches the precision displayed and stored by the entry form.
  double evaluateMoney(String expression) {
    final value = evaluate(expression);
    return (value * 100).roundToDouble() / 100;
  }

  void _pushNumber(StringBuffer buffer, List<double> numbers) {
    final token = buffer.toString();
    if (token.isEmpty || token == '.') {
      throw const FormatException('Complete the calculation');
    }
    final parsed = double.tryParse(token);
    if (parsed == null || !parsed.isFinite) {
      throw const FormatException('Enter a valid amount');
    }
    numbers.add(parsed);
    buffer.clear();
  }

  bool _isDigit(String character) {
    final code = character.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }
}
