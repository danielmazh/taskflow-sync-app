import '../models/task.dart';
import '../state/task_store.dart';

/// Seam for turning freeform user text (typed or spoken) into a [Task].
/// The current [PlainParser] is intentionally trivial — it copies the raw
/// text into the title and leaves everything else null. A future LLM-backed
/// implementation can replace this without touching call sites.
abstract class TaskParser {
  Task parse(String rawText);
}

class PlainParser implements TaskParser {
  const PlainParser();

  @override
  Task parse(String rawText) {
    return Task(
      id: TaskStore.newId(),
      title: rawText.trim(),
    );
  }
}
