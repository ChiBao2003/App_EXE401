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

• current_time      → Ngày/giờ/múi giờ thực tế hiện tại của người dùng, kèm
                       week_position và windows (this_week / last_7_days /
                       last_15_days) ĐÃ ĐƯỢC TÍNH SẴN. Dùng nguyên các mốc này,
                       KHÔNG tự tính lại ngày.
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
QUY TẮC THỜI GIAN CỐT LÕI (BẮT BUỘC)
================================================================================
1. MỐC NEO: current_time.current_date là "hôm nay". Luôn xác định hôm nay là
   thứ mấy (current_time.weekday) trước khi phân tích. KHÔNG dùng ngày hard-code.
2. "TUẦN NÀY" = tuần lịch từ Thứ Hai đến Chủ Nhật hiện tại. Nếu hôm nay là Thứ Hai
   thì tuần này mới có 1 ngày; digital_twin.period_stats.this_week gần như
   trống. TUYỆT ĐỐI không lấy dữ liệu tuần trước rồi gọi là "tuần này".
3. "1 TUẦN GẦN ĐÂY / 7 NGÀY QUA" = 7 ngày lùi từ hôm nay (hôm nay - 6 → hôm nay)
   = period_stats.last_7_days.
4. "1 THÁNG / 30 NGÀY": hệ thống CHỈ lưu 15 ngày gần nhất (cũ hơn tự xóa). Khi
   người dùng hỏi mốc > 15 ngày: chỉ phân tích period_stats.last_15_days và
   nói rõ: "Hệ thống chỉ lưu dữ liệu 15 ngày gần nhất, đây là phân tích dựa
   trên 15 ngày qua."
5. NGỮ CẢNH CHU KỲ (current_time.week_position.phase):
   - dau_tuan (Thứ 2-3): tập trung LẬP KẾ HOẠCH cho các ngày còn lại, dựa vào
     thói quen last_7_days/last_15_days; không bịa số liệu cho ngày chưa diễn ra.
   - giua_tuan (Thứ 4-5): vừa đánh giá phần đã làm vừa điều chỉnh kế hoạch.
   - cuoi_tuan (Thứ 6-CN): ĐÁNH GIÁ & tổng kết tuần, gợi ý bù/nghỉ cuối tuần.
6. Khi period_stats của một cửa sổ có session_count = 0 hoặc avg_focus = null:
   nói thẳng là chưa có dữ liệu, KHÔNG suy diễn.

================================================================================
QUY TẮC TRẢ LỜI (BẮT BUỘC)
================================================================================
Trả lời TRỰC TIẾP bằng ngôn ngữ tự nhiên. KHÔNG sử dụng bất kỳ thẻ XML nào
(không dùng <thinking>, <final_response>, hay tag nào khác).
Trước khi trả lời, tự kiểm tra trong đầu:
"Câu trả lời đã dùng đúng dữ liệu Digital Twin chưa? Đã cá nhân hóa chưa?"

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

3. Khi confidence < 0.5: Luôn thêm câu "Lưu ý: Hệ thống chưa có ================================================================================
QUY TẮC VIẾT CÂU TRẢ LỜI — NGÔN NGỮ TỰ NHIÊN (BẮT BUỘC)
================================================================================
Câu trả lời sẽ hiển thị trực tiếp trên màn hình App cho người dùng.
DO ĐÓ TUYỆT ĐỐI:
✗ KHÔNG nhắc đến tên nguồn dữ liệu nội bộ như:
  "RAG Document", "TÀI LIỆU LỊCH SỎ", "AI Ranking", "TOP_RECOMMENDATION",
  "DIGITAL TWIN", "context_payload", "features_used", "reason_codes".
✗ KHÔNG để lộ cấu trúc JSON, tên field hay key.
✗ KHÔNG sử dụng bất kỳ thẻ XML nào (<thinking>, <final_response>...).

✓ Chỉ dùng ngôn ngữ TỰ NHIÊN, THÂN THIỆN như một người bạn đang trò chuyện.
✓ Diễn đạt lại thông tin hệ thống thành câu nói tự nhiên.
  ❌ Sai: "TOP_RECOMMENDATION khuyến nghị 40/10"
  ✅ Đúng: "Hệ thống gợi ý chu kỳ 40 phút làm / 10 phút nghỉ"
================================================================================_alarm
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
# Sử dụng các model đang HOẠT ĐỘNG THỰC TẾ (200 OK) có Quota còn trống
GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta"
GEMINI_MODEL_CHAIN = [
    "models/gemini-flash-lite-latest",
    "models/gemini-3.5-flash",
    "models/gemini-3.5-flash-lite",
]
EVALUATOR_MODEL = "models/gemini-flash-lite-latest"

import re
import unicodedata

def _normalize_text(text: str) -> str:
    """Chuẩn hóa văn bản: xóa dấu câu, chuyển chữ thường, bỏ dấu tiếng Việt (kể cả đ/Đ)."""
    if not text:
        return ""
    text = text.translate(str.maketrans('đĐ', 'dd'))
    text = unicodedata.normalize('NFD', text)
    text = ''.join(c for c in text if unicodedata.category(c) != 'Mn')
    text = text.lower()
    text = re.sub(r'[^\w\s]', '', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text

class AICoachOrchestrator:
    def __init__(self, api_key: str = ""):
        self.api_key = api_key or os.getenv("GEMINI_API_KEY", "")
        if not self.api_key:
            logger.warning("[AI_COACH] GEMINI_API_KEY not found in env or init. Running in rule-based fallback mode.")
        else:
            masked = self.api_key[:6] + "..." + self.api_key[-4:] if len(self.api_key) > 10 else "***"
            logger.info(f"[AI_COACH] Initialized with GEMINI_API_KEY: {masked}")

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
        
        # 1. RAG Context (graceful degradation - RÁG lỗi không làm crash AI Coach)
        rag_context = ""
        try:
            rag_svc = RAGService(api_key=self.api_key)
            rag_context = await rag_svc.search_context(user_id=user_id, query=user_prompt)
            if rag_context:
                logger.info("[RAG] Found relevant context")
        except Exception as e:
            logger.warning(f"[RAG] Error (non-fatal, continuing without RAG): {repr(e)}")
            rag_context = ""

        # 2. Extract Features + Ranking (graceful degradation)
        from application.ai.time_window import build_time_context
        current_time_info = build_time_context()
        current_hour = current_time_info["hour"]

        features = {}
        top_rec_dict = {}
        top_k_candidates = []

        try:
            features = FeatureEngine.extract_features(digital_twin, context, current_hour)
            
            # 3. Candidate Generation
            candidates = CandidateGenerator.generate_pomodoro_candidates()
            
            # 4. Base Ranking
            ranker = RankingEngine(features)
            scored_candidates = [ranker.score_pomodoro(c) for c in candidates]
            
            # 5. Context Re-ranking
            burnout_risk = digital_twin.get("burnout")
            if not burnout_risk and "burnout_risk_score" in digital_twin:
                b_score = float(digital_twin["burnout_risk_score"] or 0)
                burnout_risk = {
                    "burnout_risk_score": b_score,
                    "risk_level": "CRITICAL" if b_score >= 70 else ("HIGH" if b_score >= 50 else ("MODERATE" if b_score >= 30 else "LOW"))
                }
            burnout_risk = burnout_risk or {}
            re_ranker = ContextReRanker(burnout_risk, context, features)
            final_candidates = re_ranker.re_rank(scored_candidates)
            
            top_rec = final_candidates[0] if final_candidates else None
            top_rec_dict = top_rec.model_dump() if top_rec else {}
            top_k_candidates = [c.model_dump() for c in final_candidates[:5]]

            # 6. Burnout Policy Enforcement (backend override - Gemini CANNOT bypass)
            burnout_score = (
                digital_twin.get("burnout", {}).get("burnout_risk_score")
                if isinstance(digital_twin.get("burnout"), dict)
                else None
            )
            if burnout_score is None:
                burnout_score = digital_twin.get("burnout_risk_score", 0)
            burnout_score = float(burnout_score or 0)

            if burnout_score >= 85 and top_rec_dict:
                top_rec_dict["work_min"] = 10
                top_rec_dict["break_min"] = 20
                top_rec_dict["reason_codes"] = ["BURNOUT_EMERGENCY_OVERRIDE"]
                logger.info(f"[RANKING] Burnout EMERGENCY override: 10/20 (score={burnout_score})")
            elif burnout_score >= 70 and top_rec_dict:
                top_rec_dict["work_min"] = 15
                top_rec_dict["break_min"] = 15
                top_rec_dict["reason_codes"] = ["BURNOUT_HIGH_OVERRIDE"]
                logger.info(f"[RANKING] Burnout HIGH override: 15/15 (score={burnout_score})")

            logger.info(f"[RANKING] Top rec: {top_rec_dict.get('work_min', '?')}/{top_rec_dict.get('break_min', '?')}")
        except Exception as e:
            logger.warning(f"[RANKING] Error (non-fatal, continuing without ranking): {repr(e)}")

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
        
        # --- Validate context payload (prevent None/NaN/ObjectId crashing JSON) ---
        def _safe_json(obj):
            if obj is None:
                return None
            if isinstance(obj, float):
                if obj != obj or obj == float('inf') or obj == float('-inf'):
                    return None
                return obj
            if isinstance(obj, dict):
                return {k: _safe_json(v) for k, v in obj.items()}
            if isinstance(obj, list):
                return [_safe_json(v) for v in obj]
            if hasattr(obj, '__str__') and not isinstance(obj, (str, int, float, bool)):
                return str(obj)
            return obj

        context_payload_safe = _safe_json(context_payload)

        full_user_content = (
            f"{rag_context}\n\n" if rag_context else ""
        ) + (
            f"DỮ LIỆU DIGITAL TWIN & RANKING Hiện Tại:\n{json.dumps(context_payload_safe, ensure_ascii=False, indent=2)}"
            f"\n\nYÊU CẦU CỦA NGƯỜI DÙNG: {user_prompt}"
        )

        # --- Gọi Gemini API (Hybrid Architecture) ---
        # Flow: 1 PRIMARY GEMINI CALL → Evaluator (1 call max) → nếu fail retry 1 lần → done
        if not self.api_key:
            fallback_reason = "GEMINI_API_KEY is empty or not configured"
            logger.warning(f"[FALLBACK] {fallback_reason}")
            res = self._rule_based(digital_twin, context, context_payload, user_prompt=user_prompt)
            res["ai_ranking"] = context_payload.get("ai_ranking", {})
            res["fallback_reason"] = fallback_reason
            return res

        masked_key = self.api_key[:6] + "..." + self.api_key[-4:] if len(self.api_key) > 10 else "***"
        logger.info(f"[GEMINI] Calling chat() for user={user_id}, prompt='{user_prompt[:60]}...' with API_KEY={masked_key}")

        try:
            import re
            res = await self._call_gemini(full_user_content, context_payload_safe, chat_history or [])

            reply_text = res.get("reply", "").strip()

            # Clean XML tags nếu Gemini vẫn output chúng (legacy prompt behavior)
            reply_text = re.sub(r'<thinking_and_evaluating>.*?</thinking_and_evaluating>', '', reply_text, flags=re.DOTALL).strip()
            match = re.search(r'<final_response>(.*?)</final_response>', reply_text, re.DOTALL)
            if match:
                reply_text = match.group(1).strip()

            # --- Evaluator: 1 call tối đa, fail-open ---
            try:
                eval_passed, eval_feedback = await self._evaluate_response(user_prompt, reply_text, context_payload_safe)
                if not eval_passed:
                    logger.info(f"[EVALUATOR] Rejected. Feedback: {eval_feedback}. Retrying once...")
                    retry_prompt = full_user_content + f"\n\n[SỬA LẠI]: {eval_feedback}"
                    res = await self._call_gemini(retry_prompt, context_payload_safe, chat_history or [])
                    reply_text = res.get("reply", "").strip()
                    reply_text = re.sub(r'<thinking_and_evaluating>.*?</thinking_and_evaluating>', '', reply_text, flags=re.DOTALL).strip()
                    match = re.search(r'<final_response>(.*?)</final_response>', reply_text, re.DOTALL)
                    if match:
                        reply_text = match.group(1).strip()
                    logger.info("[EVALUATOR] Accepted retry (no further evaluation)")
                else:
                    logger.info("[EVALUATOR] Passed")
            except Exception as eval_err:
                logger.warning(f"[EVALUATOR] Error (fail-open, accepting response): {repr(eval_err)}")

            res["reply"] = reply_text
            res["ai_ranking"] = context_payload.get("ai_ranking", {})
            logger.info(f"[GEMINI] Done. Source={res.get('source', '?')}, tools={len(res.get('tool_calls', []))}")
            return res

        except Exception as e:
            logger.exception(f"[GEMINI] Unhandled Exception during Gemini call: {repr(e)}")
            fallback_reason = f"Gemini API failure: {type(e).__name__} - {str(e)}"
            logger.error(f"[FALLBACK] Falling back to rule-based. Reason: {fallback_reason}")
            res = self._rule_based(digital_twin, context, context_payload, user_prompt=user_prompt)
            res["ai_ranking"] = context_payload.get("ai_ranking", {})
            res["fallback_reason"] = fallback_reason
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

            for retry in range(2):  # Max 2 attempts per model
                try:
                    async with httpx.AsyncClient(timeout=60.0) as client:
                        resp = await client.post(
                            api_url,
                            json=payload,
                            params={"key": self.api_key},  # dùng query param thay vì header
                            headers={"Content-Type": "application/json"}
                        )
                        resp.raise_for_status()
                        data = resp.json()
                        used_model = model_name
                        success = True
                        break
                except httpx.HTTPStatusError as e:
                    status = e.response.status_code
                    last_error = e
                    if status == 400:
                        # 400 = request body sai → log rõ, KHÔNG retry/fallback
                        logger.error(f"[GEMINI] 400 Bad Request from {model_name}: {e.response.text[:300]}")
                        raise  # Raise immediately, don't try other models
                    elif status == 429:
                        logger.warning(f"[GEMINI] [{model_name}] Quota 429 Exceeded. Moving to next model immediately.")
                        break
                    elif status in [500, 502, 503, 504] and retry < 1:
                        wait_secs = (retry + 1) * 2
                        logger.warning(f"[GEMINI] [{model_name}] API {status}. Retry in {wait_secs}s (attempt {retry+1}/2)")
                        await asyncio.sleep(wait_secs)
                        continue
                    else:
                        logger.warning(f"[GEMINI] [{model_name}] API {status}. Moving to next model.")
                        break
                except httpx.RequestError as e:
                    last_error = e
                    if retry < 1:
                        wait_secs = (retry + 1) * 2
                        logger.warning(f"[GEMINI] [{model_name}] Network error. Retry in {wait_secs}s (attempt {retry+1}/2)")
                        await asyncio.sleep(wait_secs)
                        continue
                    logger.warning(f"[GEMINI] [{model_name}] Network error. Moving to next model.")
                    break

            if success:
                logger.info(f"[GEMINI] OK: model={model_name}")
                break
            else:
                logger.warning(f"[GEMINI] [{model_name}] Failed: {repr(last_error)}. Trying next model...")
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
                    params={"key": self.api_key},
                    headers={"Content-Type": "application/json"}
                )
                resp.raise_for_status()
                data = resp.json()

            text = data["candidates"][0]["content"]["parts"][0]["text"]
            eval_result = json.loads(text)
            return eval_result.get("passed", True), eval_result.get("feedback", "")
        except Exception as e:
            logger.error(f"Evaluator error: {repr(e)}")
            return True, "" # Fail-open: nếu Evaluator lỗi (API sập, timeout...) thì cho qua (tránh crash)

    def _rule_based(self, digital_twin: Dict, context: Dict, context_payload: Dict, user_prompt: str = "") -> Dict[str, Any]:
        """Fallback rule-based thông minh khi Gemini không khả dụng."""
        tool_calls: List[Dict[str, Any]] = []
        prompt_norm = _normalize_text(user_prompt)

        # 1. Conversation intent: Chào hỏi đơn giản (helo!, hello ban, xin chao, ban la ai...)
        greetings = ["helo", "hello", "hi", "xin chao", "chao", "chao ban", "alo", "halo"]
        thanks = ["cam on", "thanks", "thank you", "cam on ban"]
        who_are_you = ["ban la ai", "ten gi", "ban la gi"]

        if any(prompt_norm == g or prompt_norm.startswith(g + " ") for g in greetings):
            return {
                "reply": "Chào bạn! Tôi là POMO Coach — Trợ lý Năng suất Cá nhân của bạn. Hôm nay bạn muốn tôi gợi ý chu kỳ Pomodoro, lập lịch làm việc hay phân tích năng suất?",
                "tool_calls": [],
                "source": "rule-based-v2"
            }
        
        if any(t in prompt_norm for t in thanks):
            return {
                "reply": "Không có gì! Rất vui được đồng hành cùng bạn. Chúc bạn một ngày làm việc thật hiệu quả! 🚀",
                "tool_calls": [],
                "source": "rule-based-v2"
            }

        if any(w in prompt_norm for w in who_are_you):
            return {
                "reply": "Tôi là POMO Coach — Cố vấn năng suất cá nhân hóa được tích hợp với Smart Watch IoT. Tôi giúp bạn tối ưu thời gian làm việc Pomodoro, quản lý lịch trình và phòng ngừa burnout dựa trên hồ sơ Digital Twin của bạn!",
                "tool_calls": [],
                "source": "rule-based-v2"
            }

        def _get_burnout(dt):
            val = dt.get("burnout_risk_score")
            if val is None and isinstance(dt.get("burnout"), dict):
                val = dt.get("burnout", {}).get("burnout_risk_score")
            return float(val or 0)

        # 2. Action intents: Yêu cầu đặt pomodoro / đặt báo thức / thông báo / lập lịch
        if any(k in prompt_norm for k in ["dat pomodoro", "bat dau pomodoro", "bat dau hoc"]):
            # Check burnout override
            burnout = _get_burnout(digital_twin)
            if burnout >= 70:
                tool_calls.append({"tool": "set_pomodoro_cycle", "params": {"work_min": 15, "break_min": 15}})
                reply = "⚠️ Cảnh báo Burnout: Chỉ số rủi ro kiệt sức của bạn đang cao (≥70). Tôi đã cưỡng chế thiết lập chu kỳ khẩn cấp 15 phút làm / 15 phút nghỉ để bảo vệ sức khỏe của bạn."
            else:
                top_rec = context_payload.get("ai_ranking", {}).get("top_recommendation", {})
                w_min = top_rec.get("work_min", 25)
                b_min = top_rec.get("break_min", 5)
                tool_calls.append({"tool": "set_pomodoro_cycle", "params": {"work_min": w_min, "break_min": b_min}})
                reply = f"Đã thiết lập chu kỳ Pomodoro {w_min} phút làm việc / {b_min} phút nghỉ ngơi phù hợp với trạng thái hiện tại của bạn. Chúc bạn tập trung tốt! 🎯"
            return {"reply": reply, "tool_calls": tool_calls, "source": "rule-based-v2"}

        if any(k in prompt_norm for k in ["bao thuc", "dat alarm"]):
            tool_calls.append({"tool": "sync_watch_alarm", "params": {"time": "07:00", "label": "Nhắc nhở học tập"}})
            return {"reply": "Đã đồng bộ báo thức 07:00 lên Smart Watch cho bạn! ⏰", "tool_calls": tool_calls, "source": "rule-based-v2"}

        if any(k in prompt_norm for k in ["thong bao", "nhac nho"]):
            tool_calls.append({"tool": "push_watch_notification", "params": {"title": "Nhắc nhở học tập", "body": "Đã đến giờ học Pomodoro!", "priority": 1}})
            return {"reply": "Đã gửi thông báo nhắc nhở lên màn hình Smart Watch! 📲", "tool_calls": tool_calls, "source": "rule-based-v2"}

        if any(k in prompt_norm for k in ["lap lich", "len lich", "xep lich"]):
            tool_calls.append({"tool": "generate_work_schedule", "params": {"target_date": "hôm nay", "grade_score": 85, "grade_letter": "A", "grade_rationale": "Lịch trình tối ưu theo nhịp sinh học", "schedule_blocks": [], "total_work_minutes": 120, "total_break_minutes": 30}})
            return {"reply": "Đã lập lịch làm việc cá nhân hóa cho bạn dựa trên lịch sử tập trung trong ngày! 📅", "tool_calls": tool_calls, "source": "rule-based-v2"}

        # 2b. Status inquiry intent: "trạng thái của tôi có tốt để làm việc tiếp không"
        if any(k in prompt_norm for k in ["trang thai", "co tot", "lam viec tiep", "co nen hoc", "phong do"]):
            stress_val = digital_twin.get("stress_level")
            burnout_val = _get_burnout(digital_twin)
            
            if burnout_val >= 70:
                reply = f"⚠️ Cảnh báo: Trạng thái của bạn đang ở mức nguy cơ kiệt sức cao (Burnout: {burnout_val}/100). Bạn KHÔNG NÊN làm việc căng thẳng tiếp lúc này. Hãy nghỉ ngơi 15-20 phút!"
            elif stress_val is not None and stress_val > 70:
                reply = f"⚠️ Mức stress của bạn hiện tại khá cao ({stress_val:.1f}/100). Bạn nên tạm nghỉ 10 phút trước khi tiếp tục công việc nhé!"
            else:
                stress_str = f"{stress_val:.1f}/100" if stress_val is not None else "thấp (an toàn)"
                reply = (
                    f"✅ Trạng thái của bạn hiện tại RẤT TỐT để tiếp tục làm việc!\n\n"
                    f"• Mức Stress: {stress_str} (thấp & an toàn)\n"
                    f"• Năng lượng/Burnout: {burnout_val}/100 (bình thường)\n\n"
                    f"👉 Hệ thống khuyến nghị bạn bắt đầu một phiên Pomodoro 25-30 phút ngay bây giờ để duy trì hiệu suất cao nhất! 🚀"
                )
            return {"reply": reply, "tool_calls": tool_calls, "source": "rule-based-v2"}

        # 2c. Clarification / Follow-up intent: "là sao", "tại sao", "giải thích", "sao vậy", "nghĩa là sao"
        clarifications = ["la sao", "tai sao", "sao vay", "nghia la sao", "giai thich", "sao the"]
        if any(prompt_norm == c or prompt_norm.startswith(c + " ") or c in prompt_norm for c in clarifications):
            stress_val = digital_twin.get("stress_level")
            burnout_val = _get_burnout(digital_twin)
            phone_usage = digital_twin.get("phone_usage") or {}
            dist_min = phone_usage.get("distraction_time_min", 0)
            unlocks = phone_usage.get("unlocks", 0)
            top_dist = phone_usage.get("top_distraction_apps", "Không có")

            reasons = []
            if stress_val is not None:
                reasons.append(f"• Mức Stress của bạn hiện tại là {stress_val:.1f}/100.")
            if dist_min and dist_min > 60:
                reasons.append(f"• Bạn đã dành {dist_min} phút cho các app giải trí ({top_dist}).")
            if unlocks and unlocks > 30:
                reasons.append(f"• Bạn đã mở khóa điện thoại {unlocks} lần hôm nay.")

            reasons_text = "\n".join(reasons) if reasons else "• Bạn đang có chỉ số hoạt động bình thường."

            reply = (
                f"Ý của tôi là dựa trên các dữ liệu thực tế thu thập từ thiết bị của bạn:\n\n"
                f"{reasons_text}\n\n"
                f"👉 Do đó, tôi muốn đưa ra khuyến nghị giúp bạn chú ý hơn để duy trì phong độ tập trung tốt nhất! 🎯"
            )
            return {"reply": reply, "tool_calls": [], "source": "rule-based-v2"}

        # 2d. Session counting intent: "hôm nay tôi học mấy phiên", "mấy phiên rồi", "đã học được bao nhiêu phiên"
        session_queries = ["may phien", "bao nhieu phien", "hoc may phien", "may phien hoc", "da hoc may phien"]
        if any(sq in prompt_norm for sq in session_queries):
            today_sessions = digital_twin.get("today_sessions_detail", [])
            total_count = len(today_sessions) if today_sessions else digital_twin.get("total_sessions", 0)
            
            if total_count == 0:
                reply = "📚 Hôm nay bạn chưa hoàn thành phiên Pomodoro nào. Hãy bắt đầu một phiên 25 phút ngay để duy trì nhịp tập trung nhé! 🚀"
            else:
                session_lines = []
                for idx, s in enumerate(today_sessions[:5], 1):
                    st = s.get("start_time", "?")
                    et = s.get("end_time", "?")
                    wm = s.get("work_min", 25)
                    tt = s.get("task_type", "general")
                    session_lines.append(f"  • Phiên {idx}: {st} → {et} ({wm} phút, {tt})")
                
                details_str = "\n".join(session_lines)
                reply = (
                    f"📚 Hôm nay bạn đã hoàn thành tổng cộng **{total_count} phiên Pomodoro**:\n\n"
                    f"{details_str}\n\n"
                    f"👉 Bạn muốn tiếp tục phiên tiếp theo ngay bây giờ không? 🎯"
                )
            return {"reply": reply, "tool_calls": [], "source": "rule-based-v2"}

        # 3. Productivity / General Query: Phân tích chỉ số Digital Twin
        tips = []
        total_sessions = digital_twin.get("total_sessions", 0)
        today_sessions = digital_twin.get("today_sessions_detail", [])
        
        stress = digital_twin.get("stress_level")
        efficiency = digital_twin.get("efficiency")
        focus = digital_twin.get("focus_score")
        temp = context.get("temperature")

        # Nếu chưa có phiên làm việc (0.0/100), coi là None để hiển thị "chưa có dữ liệu"
        if total_sessions == 0 and not today_sessions:
            if efficiency == 0.0:
                efficiency = None
            if focus == 0.0:
                focus = None

        phone_usage = digital_twin.get("phone_usage") or {}
        unlocks = phone_usage.get("unlocks")
        dist_min = phone_usage.get("distraction_time_min")
        top_dist = phone_usage.get("top_distraction_apps")

        if stress is None:
            tips.append("Hệ thống chưa có đủ dữ liệu phiên làm việc để đánh giá stress của bạn. Hãy hoàn thành vài phiên Pomodoro để nhận khuyến nghị cá nhân hóa nhé! 📊")
        elif stress > 70:
            tips.append("Tôi nhận thấy mức stress của bạn đang khá cao. Hãy thử nghỉ ngơi 10 phút, hít thở sâu hoặc đi dạo ngắn nhé! 🧘")
            tool_calls.append({"tool": "set_pomodoro_cycle", "params": {"work_min": 20, "break_min": 10}})
        elif stress > 50:
            tips.append("Mức stress đang ở mức trung bình. Hãy duy trì nhịp làm việc đều đặn và nhớ nghỉ giải lao đúng giờ! 💪")
            tool_calls.append({"tool": "set_pomodoro_cycle", "params": {"work_min": 25, "break_min": 7}})
        else:
            tips.append("Tuyệt vời! Mức stress của bạn đang rất tốt. Đây là lúc tốt nhất để tập trung làm việc hiệu quả! 🚀")
            tool_calls.append({"tool": "set_pomodoro_cycle", "params": {"work_min": 30, "break_min": 5}})

        if temp is not None:
            if temp > 33:
                tips.append(f"Nhiệt độ ngoài trời đang khá nóng ({temp:.1f}°C). Hãy uống đủ nước và làm việc ở nơi mát mẻ nhé! 🌡️")
            elif temp < 20:
                tips.append(f"Thời tiết hôm nay mát mẻ ({temp:.1f}°C), rất phù hợp để tập trung làm việc! 🍃")

        if dist_min is not None and dist_min > 120:
            tips.append(f"Hôm nay bạn đã dùng app giải trí {dist_min} phút rồi đó. Hãy cân nhắc giảm bớt thời gian sử dụng nhé! 📱")
        if unlocks is not None and unlocks > 50:
            tips.append(f"Bạn đã mở khóa điện thoại {unlocks} lần hôm nay — có vẻ hơi bị phân tâm. Thử bật chế độ không làm phiền khi làm việc nhé! 🔕")
        if top_dist and top_dist != "Không có":
            tips.append(f"Các app giải trí ({top_dist}) đang chiếm khá nhiều thời gian. Hãy thử giới hạn thời gian sử dụng chúng! 🎯")

        if efficiency is not None:
            if efficiency < 50:
                tips.append("Hiệu suất làm việc đang thấp hơn bình thường. Thử chia nhỏ công việc và bắt đầu từ việc dễ nhất trước nhé! 📋")
            elif efficiency > 80:
                tips.append("Hiệu suất của bạn rất ấn tượng! Tiếp tục duy trì phong độ này nhé! ⭐")

        fmt = lambda v, unit="/100": "chưa có dữ liệu" if v is None else f"{v}{unit}"
        greeting = "Chào bạn! Đây là phân tích nhanh từ Kilo Coach:\n\n"
        reply_text = greeting + "\n".join(f"• {tip}" for tip in tips)
        reply_text += (f"\n\n📊 Tổng quan: Stress {fmt(stress)} | Hiệu suất {fmt(efficiency)} | "
                       f"Tập trung {fmt(focus)} | Nhiệt độ {fmt(None if temp is None else round(temp, 1), '°C')}")
        if tool_calls:
            reply_text += "\n\n_💡 Tôi đã tự động điều chỉnh Pomodoro phù hợp với tình trạng hiện tại của bạn._"

        return {
            "reply": reply_text,
            "tool_calls": tool_calls,
            "source": "rule-based-v2"
        }
