/// Maps the raw grade codes used in the data model (Postgres enum, Qdrant metadata,
/// API params) to the names students actually use. Only the *display* differs —
/// every API call still sends/receives the raw code (e.g. 'B4'), never the label.
const gradeLabels = {
  'B4': 'Class 4',
  'B5': 'Class 5',
  'B6': 'Class 6',
  'B7': 'JHS 1',
  'B8': 'JHS 2',
  'B9': 'JHS 3',
  'SHS1': 'SHS 1',
  'SHS2': 'SHS 2',
  'SHS3': 'SHS 3',
};

String gradeLabel(String? code) => gradeLabels[code] ?? code ?? '';
