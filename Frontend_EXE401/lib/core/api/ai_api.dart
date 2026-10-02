import "api_client.dart";
import "dart:ui";

/// AI Feature API - Adaptive Pomodoro, Burnout Risk, Coach Advice.
class AiApi {
  static const _base = "/api/v1/ai";
  static const _ctx  = "/api/v1/context";

  // ============================================================
  // Adaptive Pomodoro
  // ============================================================

  /// Lay goi y chu ky Pomodoro tu Q-Learning Agent.
  static Future<AiRecommendation> getPomodoroRecommendation({
    double concentrationScore = 60.0,
    String taskType = "general",
  }) async {
    final data = await ApiClient.get("$_base/pomodoro/recommend", params: {
      "concentration_score": concentrationScore.toString(),
      "task_type": taskType,
    });
    return AiRecommendation.fromJson(data);
  }

  /// Gui ket qua phien de AI hoc tiep (cap nhat Q-table).
  static Future<void> sendSessionFeedback({
    required String userId,
    required String sessionId,
    required int workMin,
    required int breakMin,
    required double concentrationScore,
    required double completionRate,
    required int interruptions,
    required bool breakSkipped,
    required String taskType,
  }) async {
    final now = DateTime.now();
    await ApiClient.post("$_base/pomodoro/feedback", {
      "user_id": userId,
      "session_id": sessionId,
      "work_min": workMin,
      "break_min": breakMin,
      "concentration_score": concentrationScore,
      "completion_rate": completionRate,
      "interruptions": interruptions,
      "break_skipped": breakSkipped,
      "task_type": taskType,
      "hour_of_day": now.hour,
      "day_of_week": now.weekday - 1,
    });
  }

  // ============================================================
  // Burnout Risk
  // ============================================================

  /// Lay danh gia nguy co Burnout dua tren 7 ngay gan nhat.
  static Future<BurnoutRisk> getBurnoutRisk() async {
    final data = await ApiClient.get("$_base/burnout/risk");
    return BurnoutRisk.fromJson(data);
  }

  // ============================================================
  // Daily Coach Advice
  // ============================================================

  /// Lay loi khuyen AI cho hom nay.
  static Future<CoachAdvice> getDailyAdvice() async {
    final data = await ApiClient.get("$_base/coach/daily-advice");
    return CoachAdvice.fromJson(data);
  }

  // ============================================================
  // Context (Weather + Advice)
  // ============================================================

  /// Lay thong tin ngu canh hom nay (thoi tiet + loi khuyen).
  static Future<Map<String, dynamic>> getTodayContext({
    double lat = 10.762622,
    double lon = 106.660172,
  }) async {
    return await ApiClient.get("$_ctx/today", params: {
      "lat": lat.toString(),
      "lon": lon.toString(),
    });
  }
}

// ============================================================
// Data Models (DTOs)
// ============================================================

class AiRecommendation {
  final int workMin;
  final int breakMin;
  final String reason;
  final double confidence;
  final String source;

  AiRecommendation({
    required this.workMin,
    required this.breakMin,
    required this.reason,
    required this.confidence,
    required this.source,
  });

  factory AiRecommendation.fromJson(Map<String, dynamic> j) => AiRecommendation(
    workMin: j["work_min"] ?? 25,
    breakMin: j["break_min"] ?? 5,
    reason: j["reason"] ?? "",
    confidence: (j["confidence"] ?? 0.8).toDouble(),
    source: j["source"] ?? "q_learning",
  );
}

class BurnoutRisk {
  final double riskScore;
  final String riskLevel;
  final List<String> indicators;
  final String advice;

  BurnoutRisk({
    required this.riskScore,
    required this.riskLevel,
    required this.indicators,
    required this.advice,
  });

  factory BurnoutRisk.fromJson(Map<String, dynamic> j) => BurnoutRisk(
    riskScore: (j["risk_score"] ?? 0.0).toDouble(),
    riskLevel: j["risk_level"] ?? "low",
    indicators: List<String>.from(j["indicators"] ?? []),
    advice: j["advice"] ?? "",
  );

  Color get levelColor {
    switch (riskLevel) {
      case "critical": return const Color(0xFFE53935);
      case "high":     return const Color(0xFFFF6F00);
      case "medium":   return const Color(0xFFFFB300);
      default:         return const Color(0xFF43A047);
    }
  }
}

class CoachAdvice {
  final String advice;
  final String source;
  final bool personalized;
  final Map<String, dynamic> stats;

  CoachAdvice({
    required this.advice,
    required this.source,
    required this.personalized,
    required this.stats,
  });

  factory CoachAdvice.fromJson(Map<String, dynamic> j) => CoachAdvice(
    advice: j["advice"] ?? "",
    source: j["source"] ?? "rule_based",
    personalized: j["personalized"] ?? false,
    stats: Map<String, dynamic>.from(j["stats"] ?? {}),
  );
}
