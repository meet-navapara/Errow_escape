/// Which mode a puzzle is played in; decides what completing it saves.
enum PlayMode { campaign, daily, weekly }

class PlayContext {
  final PlayMode mode;

  /// Daily: the challenge date key (yyyy-MM-dd). Weekly: the week key.
  final String? key;

  /// Weekly: 0-based puzzle index within the week.
  final int index;

  const PlayContext._(this.mode, this.key, this.index);

  const PlayContext.campaign() : this._(PlayMode.campaign, null, 0);
  const PlayContext.daily(String dateKey) : this._(PlayMode.daily, dateKey, 0);
  const PlayContext.weekly(String weekKey, int index)
    : this._(PlayMode.weekly, weekKey, index);

  bool get isCampaign => mode == PlayMode.campaign;
  bool get isDaily => mode == PlayMode.daily;
  bool get isWeekly => mode == PlayMode.weekly;
}
