"""
application/ai/ai_coach_orchestrator.py
AI Coach Orchestrator using Google Gemini API with Tool Calling.
"""
import json
import os
import logging
import httpx
from typing import Dict, Any, List

logger = logging.getLogger("ai_coach_orchestrator")

TOOLS_SCHEMA = [
    {
        "name": "set_pomodoro_cycle",
        "description": "Adjust Pomodoro timer work and break durations in minutes",
        "parameters": {
            "type": "OBJECT",
            "properties": {
                "work_min": {"type": "INTEGER", "description": "Work duration in minutes"},
                "break_min": {"type": "INTEGER", "description": "Break duration in minutes"}
            },
            "required": ["work_min", "break_min"]
        }
    },
    {
        "name": "sync_watch_alarm",
        "description": "Sync hardware RTC alarm on Smart Watch",
        "parameters": {
            "type": "OBJECT",
            "properties": {
                "time": {"type": "STRING", "description": "HH:MM time format"},
                "label": {"type": "STRING", "description": "Alarm label"}
            },
            "required": ["time", "label"]
        }
    },
    {
        "name": "push_watch_notification",
        "description": "Push immediate alert or notification onto ESP32 TFT screen",
        "parameters": {
            "type": "OBJECT",
            "properties": {
                "title": {"type": "STRING", "description": "Title text"},
                "body": {"type": "STRING", "description": "Body message"},
                "priority": {"type": "INTEGER", "description": "1 = High, 0 = Normal"}
            },
            "required": ["title", "body"]
        }
    },
    {
        "name": "generate_work_schedule",
        "description": "Generate a detailed daily work schedule with multiple time blocks, grading, and focus predictions based on Digital Twin history. Call this when user asks to plan their day, create a schedule, or organize work hours.",
        "parameters": {
            "type": "OBJECT",
            "properties": {
                "target_date": {"type": "STRING", "description": "Target date in YYYY-MM-DD format"},
                "grade_score": {"type": "NUMBER", "description": "Schedule quality score 0-100 based on how well it matches user peak focus hours"},
                "grade_letter": {"type": "STRING", "description": "Grade letter: A+, A, B, or C"},
                "grade_rationale": {"type": "STRING", "description": "Vietnamese explanation of why this grade was given based on Digital Twin data"},
                "schedule_blocks": {
                    "type": "ARRAY",
                    "description": "Ordered list of time blocks for the day",
                    "items": {
                        "type": "OBJECT",
                        "properties": {
                            "start_time": {"type": "STRING", "description": "HH:MM start time"},
                            "end_time": {"type": "STRING", "description": "HH:MM end time"},
                            "activity": {"type": "STRING", "description": "Activity description in Vietnamese"},
                            "task_type": {"type": "STRING", "description": "coding, reading, meeting, exercise, break, lunch"},
                            "work_min": {"type": "INTEGER", "description": "Pomodoro work duration for this block"},
                            "break_min": {"type": "INTEGER", "description": "Pomodoro break duration for this block"},
                            "is_break": {"type": "BOOLEAN", "description": "True if this is a rest/break block"},
                            "focus_prediction": {"type": "NUMBER", "description": "Predicted focus score 0-100 for this time slot based on history"}
                        },
                        "required": ["start_time", "end_time", "activity", "task_type", "is_break"]
                    }
                },
                "total_work_minutes": {"type": "INTEGER", "description": "Total planned work minutes"},
                "total_break_minutes": {"type": "INTEGER", "description": "Total planned break/rest minutes"},
                "burnout_safety_advice": {"type": "STRING", "description": "Vietnamese advice about burnout prevention for this schedule"}
            },
            "required": ["target_date", "grade_score", "grade_letter", "grade_rationale", "schedule_blocks", "total_work_minutes", "total_break_minutes"]
        }
    }
]

SYSTEM_PROMPT = """
================================================================================
VAI TRÒ & BẢN SẮC
================================================================================
Bạn là POMO Coach — Trợ lý AI Năng suất Cá nhân hóa thế hệ mới, được tích hợp
trực tiếp vào hệ sinh thái Smart Watch IoT.

Bạn KHÔNG phải là chatbot trả lời chung chung.
Bạn là CỐ VẤN NĂNG SUẤT CÁ NHÂN, hiểu rõ từng người dùng qua Digital Twin
Profile của họ và đưa ra hành động CỤ THỂ, CÁ NHÂN HÓA bằng Tool Calling.

Luôn nói chuyện bằng TIẾNG VIỆT tự nhiên, thân thiện, như một người bạn đồng
hành đáng tin cậy — không phải robot.

================================================================================
DỮ LIỆU BẠN NHẬN ĐƯỢC MỖI LƯỢT
================================================================================
Mỗi tin nhắn của người dùng đến kèm một khối JSON tên "DỮ LIỆU DIGITAL TWIN &
RANKING Hiện Tại" gồm:

• current_time      → Ngày/giờ/múi giờ thực tế hiện tại của người dùng.
• digital_twin      → Hồ sơ năng suất cá nhân: focus_score, stress_level,
                      efficiency, burnout_risk_score, total_sessions...
  - today_sessions_detail → DANH SÁCH CHI TIẾT từng phiên Pomodoro hôm nay,
    bao gồm: STT, start_time (giờ BẮT ĐẦU thực từ RTC đồng hồ),
    end_time (giờ KẾT THÚC thực từ RTC), work_min, break_min, pauses,
    completed, task_type (loại công việc: coding/reading/meeting/general),
    temperature (nhiệt độ °C), actual_work_secs (thời gian thực tế giây),
    concentration_score, completion_rate, ai_feedback.
    BẮT BUỘC SỬ DỤNG DỮ LIỆU NÀY để trả lời khi người dùng hỏi:
    "tôi đã học mấy phiên", "liệt kê thời gian chi tiết", "tôi làm gì
    lúc mấy giờ", "các phiên hôm nay"... Trả lời đầy đủ start_time →
    end_time, task_type, completed hay không, nhiệt độ lúc đó.
  - today_productivity_logs → DANH SÁCH CHI TIẾT productivity logs hôm nay,
    bao gồm: STT, thoi_gian (timestamp), task_type, work_min, break_min,
    concentration_score, completion_rate, interruptions, break_skipped,
    hour_of_day. DÙNG ĐỂ TRẢ LỜI khi người dùng hỏi về loại task, điểm tập
    trung cụ thể từng phiên.
• context           → Ngữ cảnh môi trường: thời tiết, nhiệt độ, location,
                      calendar_density, số sự kiện lịch hôm nay.
• watch_status      → Trạng thái Smart Watch: connected, battery, screen hiện tại.
• ai_ranking        → TOP_RECOMMENDATION (lựa chọn tốt nhất do Ranking Engine
                      tính toán) và top_k_candidates (top 5 lựa chọn thay thế).
  - features_used   → Vector đặc trưng sau normalization dùng để tính điểm.
  - reason_codes    → Lý do cụ thể tại sao hệ thống chọn lựa chọn này.

================================================================================
QUY TẮC TƯ DUY — CHAIN OF THOUGHT (BẮT BUỘC ÁP DỤNG)
================================================================================
TRƯỚC KHI sinh ra câu trả lời cuối cùng, bạn BẮT BUỘC phải viết toàn bộ luồng suy nghĩ
và tự kiểm duyệt vào trong cặp thẻ <thinking_and_evaluating>. Bạn phải tự hỏi:
"Câu trả lời của mình đã nhắc đến điểm số, trạng thái phiên (nếu có), và cá nhân hóa chưa?".
Sau khi suy nghĩ xong, bạn mới được viết câu trả lời chính thức vào cặp thẻ <final_response>.

BƯỚC 1 — KIỂM TRA THỜI GIAN & BỐI CẢNH
  → Đang là mấy giờ? Sáng/chiều/tối?
  → Ngày trong tuần? (Cần khuyên nhẹ hơn vào cuối tuần)
  → Thời tiết? Nhiệt độ? (Nóng > 34°C → giảm thời gian làm; mưa bão → không
    đề xuất hoạt động ngoài trời)

BƯỚC 2 — ĐỌC HỒ SƠ DIGITAL TWIN
  → focus_score bao nhiêu? (≥ 75: đang rất tốt; < 40: đang kém)
  → stress_level bao nhiêu? (≥ 70: stress cao, cần nghỉ dài hơn)
  → burnout_risk_score bao nhiêu? (≥ 60: CẢNH BÁO đỏ; ≥ 80: KHẨN CẤP)
  → total_sessions hôm nay? (> 8: đã làm quá nhiều)
  → efficiency bao nhiêu? (< 50: đang không hiệu quả, nên nghỉ)

BƯỚC 3 — ĐỌC TOP_RECOMMENDATION
  → work_min và break_min của Top Recommendation là bao nhiêu?
  → reason_codes nói gì? Giải thích chúng thành câu nói tự nhiên.
  → confidence thấp (< 0.5)? → Thêm câu "Hệ thống đang có ít dữ liệu về bạn,
    khuyến nghị này sẽ chính xác hơn sau vài ngày sử dụng."

BƯỚC 4 — PHÂN TÍCH YÊU CẦU NGƯỜI DÙNG
  → Người dùng muốn làm gì? (code / đọc / họp / tập thể dục / không rõ)
  → Có xung đột với hồ sơ sức khỏe không? (ví dụ: muốn làm tiếp nhưng burnout
    đang cao)
  → Có câu hỏi nào cần trả lời thêm không?

BƯỚC 5 — QUYẾT ĐỊNH TOOL NÀO CẦN GỌI
  → Xem bảng TOOL CALLING LOGIC bên dưới để quyết định.

================================================================================
TOOL CALLING LOGIC — BẮT BUỘC TUÂN THEO
================================================================================
Bạn có 4 Tool để điều khiển Smart Watch và lập lịch. Quyết định theo logic sau:

── set_pomodoro_cycle ──────────────────────────────────────────────────────────
GỌI KHI: Người dùng muốn bắt đầu làm việc / học / code / đọc sách / họp.
KHÔNG GỌI KHI: Người dùng chỉ hỏi thông tin, không có ý định bắt đầu phiên.

Thông số PHẢI LẤY từ TOP_RECOMMENDATION của ai_ranking.
KHÔNG được tự nghĩ ra work_min / break_min khác.

Ngoại lệ Burnout Override (ưu tiên tuyệt đối):
  → Nếu burnout_risk_score ≥ 70 → set {"work_min": 15, "break_min": 15}
  → Nếu burnout_risk_score ≥ 85 → set {"work_min": 10, "break_min": 20}
  → Báo rõ cho user biết đây là chế độ KHẨN CẤP và lý do.

── sync_watch_alarm ────────────────────────────────────────────────────────────
GỌI KHI: Người dùng hỏi "tôi nên bắt đầu lúc mấy giờ?" hoặc muốn đặt nhắc nhở
cụ thể (ví dụ: "nhắc tôi học lúc 9 giờ sáng mai").

Xác định giờ tốt nhất dựa trên digital_twin.focus_score theo từng khung giờ
(sáng/chiều/tối) và calendar_density (Medium/High → tránh giờ họp).

── push_watch_notification ─────────────────────────────────────────────────────
GỌI KHI:
  • burnout_risk_score ≥ 60 → Gửi cảnh báo ngay lập tức
  • Người dùng đang làm việc quá lâu không nghỉ (total_sessions > 6 trong ngày)
  • Thời tiết nguy hiểm ảnh hưởng sức khỏe (nhiệt độ > 36°C, bão...)
  • Người dùng yêu cầu gửi nhắc nhở khẩn

Nội dung thông báo: NGẮN GỌN, tối đa 2 dòng, dùng emoji phù hợp.

── generate_work_schedule ─────────────────────────────────────────────────────
GỌI KHI: Người dùng yêu cầu một trong các điều sau:
  • "lên lịch làm việc cho tôi"
  • "xếp lịch ngày mai / hôm nay / từ giờ đến tối"
  • "giờ nào nên làm gì, giờ nào nghỉ"
  • "lập kế hoạch làm việc chi tiết"
  • "tổ chức thời gian làm việc"

KHÔNG GỌI KHI: Người dùng chỉ hỏi "bắt đầu 1 phiên" đơn lẻ → dùng set_pomodoro_cycle.

QUY TẮC LẬP LỊCH (BẮT BUỘC):
  1. Phân tích task_performance trong digital_twin:
     → morning_focus (5h-12h): thường cao nhất → xếp việc KHÓ (coding, báo cáo)
     → afternoon_focus (12h-18h): thường thấp → xếp việc NHẸ (rà soát, họp, đọc)
     → evening (sau 18h): chỉ xếp nếu user yêu cầu, ưu tiên nghỉ ngơi

  2. Mỗi block phải có work_min và break_min dựa trên TOP_RECOMMENDATION:
     → Buổi sáng (focus cao): work_min dài hơn (35-45 phút)
     → Buổi chiều (focus thấp): work_min ngắn hơn (20-25 phút), break dài hơn

  3. Chấm điểm grade_score dựa trên:
     → Task khó có nằm trong khung giờ focus đỉnh không? (+30 điểm)
     → Break time >= 10 phút giữa các block? (+20 điểm)
     → Tổng phiên <= 6/ngày (an toàn burnout)? (+20 điểm)
     → Có nghỉ trưa >= 60 phút? (+15 điểm)
     → Kết thúc trước 20h? (+15 điểm)
     Quy đổi: >= 95 → A+, >= 85 → A, >= 70 → B, < 70 → C

  4. focus_prediction cho mỗi block: lấy từ task_performance tương ứng
     Ví dụ: coding buổi sáng → dùng coding_morning_focus (93.5%)
            coding buổi chiều → dùng coding_afternoon_focus (40%)

  5. burnout_safety_advice: Nếu burnout_risk_score >= 50, khuyên giảm phiên.
     Nếu >= 70, chỉ xếp tối đa 3-4 phiên nhẹ.

================================================================================
QUY TẮC CÁ NHÂN HÓA
================================================================================
1. LUÔN dùng dữ liệu Digital Twin để cá nhân hóa câu trả lời. Ví dụ:
   ❌ Sai: "Bạn nên làm việc 25 phút và nghỉ 5 phút."
   ✅ Đúng: "Dựa vào hồ sơ của bạn, điểm tập trung hiện tại đang ở mức 87/100 —
             đây là trạng thái rất tốt. Hệ thống khuyến nghị bạn tận dụng ngay
             với 40 phút làm / 10 phút nghỉ."

2. Giải thích Reason Codes thành ngôn ngữ tự nhiên:
   - HIGH_FOCUS_CAPACITY_CODING  → "Bạn đang có phong độ code rất tốt hôm nay"
   - LOW_CONFIDENCE_MISSING_DATA → "Hệ thống đang ít dữ liệu về bạn, khuyến nghị
                                    sẽ chính xác hơn sau vài ngày dùng thêm"
   - BURNOUT_RISK_HIGH           → "Dấu hiệu kiệt sức đang xuất hiện — cần nghỉ
                                    ngơi ngay"
   - CONTEXT_HOT_WEATHER         → "Thời tiết nóng làm giảm hiệu suất não bộ"
   - STRESS_ELEVATED             → "Mức độ stress của bạn đang cao hơn bình thường"

3. Khi confidence < 0.5: Luôn thêm câu "Lưu ý: Hệ thống chưa có đủ dữ liệu cá
   nhân về bạn. Khuyến nghị này dựa trên pattern phổ biến và sẽ chính xác hơn
   sau vài ngày sử dụng."

4. Câu trả lời ngắn gọn, súc tích, không quá 4-5 câu cho trường hợp thông thường.
   Dài hơn chỉ khi người dùng hỏi phân tích chuyên sâu.

================================================================================
XỬ LÝ TÌNH HUỐNG ĐẶC BIỆT
================================================================================
BURNOUT KHẨN CẤP (burnout_risk_score ≥ 75):
  → Không đề xuất làm thêm bất kỳ phiên nào.
  → Gọi push_watch_notification với cảnh báo.
  → Nếu user vẫn muốn làm → set_pomodoro_cycle với override ngắn (10/20).
  → Giọng điệu: quan tâm, chăm sóc, không phán xét.

NGƯỜI DÙNG MUỐN HOẠT ĐỘNG NGOÀI TRỜI (chạy bộ, thể dục):
  → Kiểm tra context.temperature: > 34°C → cảnh báo, đề xuất tập trong nhà
  → Kiểm tra context.weather: "Rainy" / "Stormy" → không đề xuất ngoài trời
  → Nếu an toàn → không cần gọi set_pomodoro_cycle mà gọi sync_watch_alarm
    để nhắc giờ tập phù hợp.

NGƯỜI DÙNG YÊU CẦU LẬP LỊCH LÀM VIỆC (cả ngày / ngày mai / từ giờ đến tối):
  → BẮT BUỘC gọi generate_work_schedule.
  → Phân tích task_performance để bố trí giờ phù hợp.
  → Trình bày kết quả kèm giải thích tại sao xếp lịch như vậy.
  → Nếu user nói "ngày mai" → target_date = ngày mai.
  → Nếu user nói "hôm nay" hoặc "từ giờ" → target_date = hôm nay,
    chỉ lên lịch từ giờ hiện tại trở đi.
  → Sau khi gọi generate_work_schedule, hãy tóm tắt lịch trình bằng văn bản
    tự nhiên kèm Grade và lý do chấm điểm.

NGƯỜI DÙNG HỎI TỔNG KẾT / PHÂN TÍCH:
  → KHÔNG gọi bất kỳ Tool nào.
  → Tổng hợp từ digital_twin và productivity history.
  → Chỉ ra điểm mạnh, điểm yếu, đề xuất cải thiện cụ thể.

NGƯỜI DÙNG KHÔNG RÕ MUỐN GÌ (hỏi chung chung):
  → Hỏi lại một câu ngắn để làm rõ.
  → Ví dụ: "Bạn muốn bắt đầu làm việc ngay, hay muốn tôi phân tích năng suất
             tuần này?"

================================================================================
NHỮNG ĐIỀU TUYỆT ĐỐI KHÔNG ĐƯỢC LÀM
================================================================================
✗ KHÔNG tự bịa work_min / break_min khác với TOP_RECOMMENDATION (trừ Burnout Override).
✗ KHÔNG tự tính lại điểm số ranking.
✗ KHÔNG bịa số liệu lịch sử mà không có trong digital_twin.
✗ KHÔNG gọi Tool khi người dùng chỉ đang hỏi thông tin.
✗ KHÔNG trả lời bằng tiếng Anh khi người dùng nói tiếng Việt.
✗ KHÔNG viết câu dài lan man. Mỗi câu phải có giá trị thực.
✗ KHÔNG bỏ qua burnout_risk_score ≥ 60 — đây là ưu tiên hàng đầu.

================================================================================
QUY TẮC VIẾT <final_response> — NGÔN NGỮ TỰ NHIÊN (BẮT BUỘC)
================================================================================
<final_response> là thứ người dùng đọc trực tiếp trên màn hình App.
DO ĐÓ TUYỆT ĐỐI:
✗ KHÔNG nhắc đến hoặc trích dẫn tên nguồn dữ liệu nội bộ như:
  "RAG Document", "TÀI LIỆU LỊCH SỬ", "Khuyến nghị từ AI Ranking",
  "TOP_RECOMMENDATION", "DỮ LIỆU DIGITAL TWIN", "context_payload",
  "features_used", "reason_codes", hay bất kỳ nhãn kỹ thuật nào.
✗ KHÔNG để lộ cấu trúc JSON, tên field hay key.
✗ KHÔNG copy-paste nội dung từ khối <thinking_and_evaluating> vào <final_response>.

✓ Chỉ dùng ngôn ngữ TỰ NHIÊN, THÂN THIỆN như một người bạn đang trò chuyện.
✓ Nếu muốn đề cập đến thông tin từ hệ thống, hãy diễn đạt lại thành câu nói tự nhiên.
  Ví dụ:
  ❌ Sai: "Dựa vào RAG Document, bạn quy định nhiệt độ > 33°C..."
  ✅ Đúng: "Theo thói quen cá nhân của bạn, khi nhiệt độ vượt 33°C..."
  ❌ Sai: "TOP_RECOMMENDATION khuyến nghị 40/10"
  ✅ Đúng: "Hệ thống gợi ý chu kỳ 40 phút làm / 10 phút nghỉ"
================================================================================
"""

EVALUATOR_PROMPT = """
Bạn là POMO Evaluator - Người đánh giá chất lượng AI Coach.
Nhiệm vụ của bạn là kiểm tra xem câu trả lời của AI Coach có:
1. Trả lời đúng, đầy đủ trọng tâm câu hỏi của người dùng chưa?
2. Có cá nhân hóa và sử dụng chính xác dữ liệu từ Digital Twin (điểm số, trạng thái phiên học, nhiệt độ...) không?
3. Nếu người dùng vừa có một phiên học bị bỏ cuộc / điểm thấp (< 50), AI Coach có phê bình thẳng thắn và đưa ra lời khuyên phù hợp không (hay lại đi khen sai sự thật)?

HÃY ĐÁNH GIÁ NGHIÊM KHẮC.
Nếu đạt yêu cầu: Trả về {"passed": true, "feedback": "Tốt"}
Nếu không đạt: Trả về {"passed": false, "feedback": "Lý do tại sao sai và yêu cầu AI Coach sửa lại cụ thể"}
BẮT BUỘC trả về ĐÚNG định dạng JSON.
"""

# Gemini REST API — Model Fallback Chain
# Khi model chính bị quá tải (503), tự động thử model tiếp theo trong danh sách
GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"
GEMINI_MODEL_CHAIN = [
    "gemini-3.8-flash",         # Primary — Mạnh nhất, thinking model
    "gemini-2.5-flash-lite",    # Fallback 1 — Nhẹ, ít quá tải hơn
]
EVALUATOR_MODEL = "gemini-3.8-flash"

class AICoachOrchestrator:
    def __init__(self, api_key: str = ""):
        self.api_key = api_key or os.getenv("GEMINI_API_KEY", "")
        if not self.api_key:
            logger.warning("GEMINI_API_KEY not found. Running in rule-based fallback mode.")

    async def chat(
        self,
        user_id: str,
        user_prompt: str,
        digital_twin: Dict[str, Any],
        context: Dict[str, Any],
        watch_status: Dict[str, Any],
        chat_history: List[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        from application.ai.rag_service import RAGService
        from application.ai.feature_engine import FeatureEngine
        from application.ai.ranking_engine import CandidateGenerator, RankingEngine, ContextReRanker
        from datetime import datetime, timezone, timedelta
        
        # 1. RAG Context
        rag_svc = RAGService(api_key=self.api_key)
        rag_context = await rag_svc.search_context(user_id=user_id, query=user_prompt)

        # 2. Extract Features + inject real current time
        try:
            vn_tz = timezone(timedelta(hours=7))
            now_local = datetime.now(vn_tz)
        except Exception:
            now_local = datetime.now()
        current_hour = now_local.hour
        weekday_names = ["Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy", "Chủ Nhật"]
        current_time_info = {
            "current_datetime": now_local.strftime("%Y-%m-%d %H:%M"),
            "weekday": weekday_names[now_local.weekday()],
            "hour": now_local.hour,
            "minute": now_local.minute,
            "timezone": "Asia/Ho_Chi_Minh"
        }

        features = FeatureEngine.extract_features(digital_twin, context, current_hour)
        
        # 3. Candidate Generation
        candidates = CandidateGenerator.generate_pomodoro_candidates()
        
        # 4. Base Ranking
        ranker = RankingEngine(features)
        scored_candidates = [ranker.score_pomodoro(c) for c in candidates]
        
        # 5. Context Re-ranking
        burnout_risk = digital_twin.get("burnout", {})
        re_ranker = ContextReRanker(burnout_risk, context, features)
        final_candidates = re_ranker.re_rank(scored_candidates)
        
        top_rec = final_candidates[0] if final_candidates else None
        top_rec_dict = top_rec.model_dump() if top_rec else {}
        
        # Select Top 5 for logging
        top_k_candidates = [c.model_dump() for c in final_candidates[:5]]

        context_payload = {
            "current_time": current_time_info,
            "digital_twin": digital_twin,
            "context": context,
            "watch_status": watch_status,
            "ai_ranking": {
                "top_recommendation": top_rec_dict,
                "top_k_candidates": top_k_candidates,
                "features_used": features
            }
        }
        
        full_user_content = (
            f"{rag_context}\n\n" if rag_context else ""
        ) + (
            f"DỮ LIỆU DIGITAL TWIN & RANKING Hiện Tại:\n{json.dumps(context_payload, ensure_ascii=False, indent=2)}"
            f"\n\nYÊU CẦU CỦA NGƯỜI DÙNG: {user_prompt}"
        )

        # --- Gọi Gemini API thật nếu có key (Hybrid Architecture) ---
        if self.api_key:
            try:
                feedback = None
                max_retries = 1
                
                for attempt in range(max_retries + 1):
                    # Nếu là lần thử lại, chèn thêm feedback vào prompt
                    current_prompt = full_user_content
                    if feedback:
                        current_prompt += f"\n\n[HỆ THỐNG YÊU CẦU SỬA ĐỔI LẦN {attempt}]:\nCâu trả lời trước của bạn bị Evaluator từ chối với lý do: '{feedback}'. Hãy sửa lại <thinking_and_evaluating> và viết lại <final_response> tốt hơn."
                    
                    res = await self._call_gemini(current_prompt, context_payload, chat_history or [])
                    
                    # Lọc <final_response>
                    reply_text = res.get("reply", "")
                    clean_reply = reply_text
                    
                    import re
                    match = re.search(r'<final_response>(.*?)</final_response>', reply_text, re.DOTALL)
                    if match:
                        clean_reply = match.group(1).strip()
                    else:
                        # Fallback: nếu AI không tuân thủ format, thử lấy toàn bộ bỏ qua tag nếu có
                        clean_reply = re.sub(r'<thinking_and_evaluating>.*?</thinking_and_evaluating>', '', reply_text, flags=re.DOTALL).strip()
                    
                    # Chỉ evaluate nếu không phải lần cuối
                    if attempt < max_retries:
                        eval_passed, eval_feedback = await self._evaluate_response(user_prompt, clean_reply, context_payload)
                        if eval_passed:
                            res["reply"] = clean_reply
                            res["ai_ranking"] = context_payload["ai_ranking"]
                            return res
                        else:
                            logger.info(f"Evaluator rejected response (Attempt {attempt}). Feedback: {eval_feedback}")
                            feedback = eval_feedback
                    else:
                        # Lần cuối cùng, đành chấp nhận
                        res["reply"] = clean_reply
                        res["ai_ranking"] = context_payload["ai_ranking"]
                        return res

            except Exception as e:
                import traceback
                logger.error(f"Gemini API error: {repr(e)}. Traceback: {traceback.format_exc()}")
                logger.error("Falling back to rule-based.")

        # --- Rule-based fallback ---
        res = self._rule_based(digital_twin, context, context_payload)
        res["ai_ranking"] = context_payload["ai_ranking"]
        return res

    async def _call_gemini(self, full_content: str, context_payload: Dict, chat_history: List[Dict]) -> Dict[str, Any]:
        """Gọi Gemini REST API với function calling."""
        contents = chat_history.copy()
        contents.append({
            "role": "user",
            "parts": [{"text": full_content}]
        })

        payload = {
            "system_instruction": {
                "parts": [{"text": SYSTEM_PROMPT}]
            },
            "contents": contents,
            "tools": [{"function_declarations": TOOLS_SCHEMA}],
            "generationConfig": {
                "temperature": 0.4,
                "maxOutputTokens": 8192,
                "candidateCount": 1
            }
        }

        import asyncio
        data = None
        used_model = GEMINI_MODEL_CHAIN[0]

        # --- Model Fallback Chain: thử từng model cho đến khi thành công ---
        for model_name in GEMINI_MODEL_CHAIN:
            api_url = f"{GEMINI_BASE_URL}/{model_name}:generateContent"
            last_error = None
            success = False

            for retry in range(3):
                try:
                    async with httpx.AsyncClient(timeout=60.0) as client:
                        resp = await client.post(
                            api_url,
                            json=payload,
                            headers={
                                "Content-Type": "application/json",
                                "x-goog-api-key": self.api_key
                            }
                        )
                        resp.raise_for_status()
                        data = resp.json()
                        used_model = model_name
                        success = True
                        break
                except httpx.HTTPStatusError as e:
                    status = e.response.status_code
                    if status in [429, 500, 502, 503, 504] and retry < 2:
                        wait_secs = (retry + 1) * 2  # 2s, 4s, 6s
                        logger.warning(f"[{model_name}] API {status}. Retry in {wait_secs}s (attempt {retry+1}/3)")
                        await asyncio.sleep(wait_secs)
                        last_error = e
                        continue
                    last_error = e
                    break  # Lỗi 4xx khác (401, 404) → chuyển model tiếp
                except httpx.RequestError as e:
                    if retry < 2:
                        wait_secs = (retry + 1) * 2
                        logger.warning(f"[{model_name}] Network error. Retry in {wait_secs}s (attempt {retry+1}/3)")
                        await asyncio.sleep(wait_secs)
                        last_error = e
                        continue
                    last_error = e
                    break

            if success:
                logger.info(f"Gemini OK: model={model_name}")
                break
            else:
                logger.warning(f"[{model_name}] Failed after retries: {repr(last_error)}. Trying next model...")
        else:
            # Tất cả model đều fail
            raise last_error

        # --- Parse response (xử lý thinking model content rỗng) ---
        tool_calls: List[Dict[str, Any]] = []
        reply_text = ""

        candidates = data.get("candidates", [])
        if candidates:
            candidate = candidates[0]
            finish_reason = candidate.get("finishReason", "")
            parts = candidate.get("content", {}).get("parts", [])

            for part in parts:
                if "text" in part:
                    reply_text += part["text"]
                elif "functionCall" in part:
                    fc = part["functionCall"]
                    tool_calls.append({
                        "tool": fc.get("name"),
                        "params": fc.get("args", {})
                    })

            # Thinking model có thể trả content rỗng khi MAX_TOKENS
            if not reply_text and finish_reason == "MAX_TOKENS":
                logger.warning(f"Thinking model [{used_model}] returned empty content (MAX_TOKENS). Using fallback text.")
                reply_text = "Xin lỗi, tôi đang xử lý quá nhiều thông tin. Hãy thử lại hoặc hỏi câu ngắn hơn nhé!"

        if not reply_text:
            reply_text = "Kilo Coach đã phân tích và chuẩn bị lệnh cho Smart Watch."

        return {
            "reply": reply_text,
            "tool_calls": tool_calls,
            "source": used_model
        }

    async def _evaluate_response(self, user_prompt: str, generated_reply: str, context_payload: Dict) -> tuple[bool, str]:
        """Gọi Evaluator Node để kiểm duyệt câu trả lời."""
        eval_content = (
            f"DỮ LIỆU NGƯỜI DÙNG HIỆN TẠI:\n{json.dumps(context_payload, ensure_ascii=False)}\n\n"
            f"CÂU HỎI CỦA NGƯỜI DÙNG: {user_prompt}\n\n"
            f"CÂU TRẢ LỜI CỦA AI COACH: {generated_reply}\n\n"
            "Hãy đánh giá và trả về JSON theo đúng định dạng."
        )

        payload = {
            "system_instruction": {
                "parts": [{"text": EVALUATOR_PROMPT}]
            },
            "contents": [{
                "role": "user",
                "parts": [{"text": eval_content}]
            }],
            "generationConfig": {
                "temperature": 0.1, # Cực thấp để Evaluator khách quan nhất
                "responseMimeType": "application/json"
            }
        }

        try:
            evaluator_url = f"{GEMINI_BASE_URL}/{EVALUATOR_MODEL}:generateContent"
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.post(
                    evaluator_url,
                    json=payload,
                    headers={
                        "Content-Type": "application/json",
                        "x-goog-api-key": self.api_key
                    }
                )
                resp.raise_for_status()
                data = resp.json()

            text = data["candidates"][0]["content"]["parts"][0]["text"]
            eval_result = json.loads(text)
            return eval_result.get("passed", True), eval_result.get("feedback", "")
        except Exception as e:
            logger.error(f"Evaluator error: {repr(e)}")
            return True, "" # Fail-open: nếu Evaluator lỗi (API sập, timeout...) thì cho qua (tránh crash)

    def _rule_based(self, digital_twin: Dict, context: Dict, context_payload: Dict) -> Dict[str, Any]:
        """Fallback rule-based thông minh khi Gemini không khả dụng."""
        tool_calls: List[Dict[str, Any]] = []
        tips = []

        stress = digital_twin.get("stress_level", 40)
        efficiency = digital_twin.get("efficiency", 70)
        focus = digital_twin.get("focus_score", 65)
        temp = context.get("temperature", 28)
        weather_desc = context.get("description", "")

        # Phone usage context
        phone_usage = context_payload.get("phone_usage", {})
        screen_time_min = phone_usage.get("screen_time_minutes", 0)
        unlocks = phone_usage.get("unlock_count", 0)
        distraction_apps = phone_usage.get("distraction_apps", [])

        # --- Đánh giá mức độ stress ---
        if stress > 70:
            tips.append("Tôi nhận thấy mức stress của bạn đang khá cao. Hãy thử nghỉ ngơi 10 phút, hít thở sâu hoặc đi dạo ngắn nhé! 🧘")
            tool_calls.append({"tool": "set_pomodoro_cycle", "params": {"work_min": 20, "break_min": 10}})
        elif stress > 50:
            tips.append("Mức stress đang ở mức trung bình. Hãy duy trì nhịp làm việc đều đặn và nhớ nghỉ giải lao đúng giờ! 💪")
            tool_calls.append({"tool": "set_pomodoro_cycle", "params": {"work_min": 25, "break_min": 7}})
        else:
            tips.append("Tuyệt vời! Mức stress của bạn đang rất tốt. Đây là lúc tốt nhất để tập trung làm việc hiệu quả! 🚀")
            tool_calls.append({"tool": "set_pomodoro_cycle", "params": {"work_min": 30, "break_min": 5}})

        # --- Đánh giá thời tiết ---
        if temp > 33:
            tips.append(f"Nhiệt độ ngoài trời đang khá nóng ({temp:.1f}°C). Hãy uống đủ nước và làm việc ở nơi mát mẻ nhé! 🌡️")
        elif temp < 20:
            tips.append(f"Thời tiết hôm nay mát mẻ ({temp:.1f}°C), rất phù hợp để tập trung làm việc! 🍃")

        # --- Đánh giá sử dụng điện thoại ---
        if screen_time_min > 120:
            tips.append(f"Hôm nay bạn đã dùng điện thoại {screen_time_min} phút rồi đó. Hãy cân nhắc giảm bớt thời gian sử dụng nhé! 📱")
        if unlocks > 50:
            tips.append(f"Bạn đã mở khóa điện thoại {unlocks} lần hôm nay — có vẻ hơi bị phân tâm. Thử bật chế độ không làm phiền khi làm việc nhé! 🔕")
        if distraction_apps:
            app_names = ', '.join(distraction_apps[:3])
            tips.append(f"Các app giải trí ({app_names}) đang chiếm khá nhiều thời gian. Hãy thử giới hạn thời gian sử dụng chúng! 🎯")

        # --- Đánh giá hiệu suất ---
        if efficiency < 50:
            tips.append("Hiệu suất làm việc đang thấp hơn bình thường. Thử chia nhỏ công việc và bắt đầu từ việc dễ nhất trước nhé! 📋")
        elif efficiency > 80:
            tips.append("Hiệu suất của bạn rất ấn tượng! Tiếp tục duy trì phong độ này nhé! ⭐")

        # --- Tổng hợp câu trả lời tự nhiên ---
        greeting = "Chào bạn! Đây là phân tích nhanh từ Kilo Coach:\n\n"
        reply_text = greeting + "\n".join(f"• {tip}" for tip in tips)
        reply_text += f"\n\n📊 Tổng quan: Stress {stress}/100 | Hiệu suất {efficiency}/100 | Tập trung {focus}/100 | Nhiệt độ {temp:.1f}°C"
        reply_text += "\n\n_💡 Tôi đã tự động điều chỉnh Pomodoro phù hợp với tình trạng hiện tại của bạn._"

        return {
            "reply": reply_text,
            "tool_calls": tool_calls,
            "source": "rule-based-v2"
        }
