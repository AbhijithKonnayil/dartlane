/// Replaces each `{{key}}` in [template] with its value in [values].
///
/// A placeholder with no entry in [values] is left as it is.
String renderTemplate(String template, Map<String, String> values) {
  var result = template;
  values.forEach((key, value) {
    result = result.replaceAll('{{$key}}', value);
  });
  return result;
}
