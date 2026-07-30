class WatchboardScreensBubbleData {
  Map<String, dynamic> data;
  double radius;
  double x;
  double y;
  double vx;
  double vy;

  WatchboardScreensBubbleData({required this.data, required this.radius, required this.x, required this.y, this.vx = 0.0, this.vy = 0.0});
}
