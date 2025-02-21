coverage=$1

dart format --line-length 80 .
dart analyze lib test
if [ "$coverage" = "coverage" ]; then
dart pub global activate coverage
dart pub global run coverage:test_with_coverage

echo "generating reports"

genhtml coverage/lcov.info -o coverage/html
coverage_percentage=$(lcov --summary coverage/lcov.info 2>&1 | grep "lines......" | awk '{print $2}')
open coverage/html/index.html
echo "COVERAGE : $coverage_percentage"

if (( $(echo "$coverage_percentage < 80" | bc -l) )); then
  echo "Not eligible for PR"
  exit 1
fi
fi