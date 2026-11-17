/// A reviewed wrapper contract. Library identity prevents same-name collisions.
class SemanticWrapper {
  final String widget;
  final String library;
  final String label;
  final String child;

  const SemanticWrapper({
    required this.widget,
    required this.library,
    required this.label,
    required this.child,
  });

  String get identity => '$library#$widget';

  Map<String, String> toJson() => {
        'widget': widget,
        'library': library,
        'label': label,
        'child': child,
      };
}
