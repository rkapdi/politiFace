/// Per-user, per-node state in the progression map. Computed from data in
/// ProgressionStateMachine — not stored as the source of truth, because the
/// underlying signals (card FSRS state, practice counts) move independently.
enum NodeState {
  /// Prerequisites not satisfied — the node isn't even visible in the map
  /// renderer (its subtree is collapsed under the parent).
  locked,

  /// Unlocked but the user hasn't started any tier yet.
  available,

  /// At least one card on this node has been touched, but the demonstrated-
  /// recall gate (see [ProgressionStateMachine.isTierMastered]) hasn't fired
  /// for any tier yet, or only some tiers are mastered.
  progress,

  /// Every tier of this node has cleared the demonstrated-recall gate. Child
  /// nodes flip from locked → available.
  mastered;

  bool get isVisible => this != NodeState.locked;
  bool get isStarted =>
      this == NodeState.progress || this == NodeState.mastered;
}
