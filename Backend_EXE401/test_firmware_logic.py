"""
test_firmware_logic.py
Unit test va static/algorithmic simulation cho cac logic firmware moi:
1. Buzzer dismissal khi dang ON, khi dang OFF giua nhip, va khoi dong beep moi sau dismiss.
2. Millis wrap-around overflow tai moc 49.7 ngay (0xFFFFFFFF).
3. RTC availability / validity check tren alarm scheduler.
4. Offline FIFO Queue (5 slots), reject on full, FIFO order, ACK validation, BLE reconnect retry.
"""
import ctypes


# ==============================================================================
# 1. TEST BUZZER STATE MACHINE
# ==============================================================================
class MockBuzzerHardware:
    def __init__(self):
        self.BUZZER_PIN = 23
        self.BUZZER_DUTY_SAFE = 32
        self.beepRemaining = 0
        self.beepOnTime = 0
        self.beepFreq = 0
        self.isBeepOn = False
        self.lastBeepTime = 0
        self.pwm_duty = 0
        self.gpio_level = 0
        self.attached = False

    def ledcWrite(self, pin_or_chan, duty):
        self.pwm_duty = duty
        if duty == 0:
            self.gpio_level = 0

    def ledcAttach(self, pin, freq, bits):
        self.attached = True

    def digitalWrite(self, pin, val):
        self.gpio_level = val
        if val == 0:
            self.pwm_duty = 0

    def stopBuzzer(self):
        self.beepRemaining = 0
        self.isBeepOn = False
        self.ledcWrite(self.BUZZER_PIN, 0)
        self.digitalWrite(self.BUZZER_PIN, 0)

    def startBeep(self, times, onMs, freq, now_ms):
        if times <= 0:
            self.stopBuzzer()
            return
        self.stopBuzzer()
        self.beepRemaining = times
        self.beepOnTime = onMs
        self.beepFreq = freq
        self.isBeepOn = True
        self.lastBeepTime = now_ms
        self.ledcAttach(self.BUZZER_PIN, self.beepFreq, 8)
        self.ledcWrite(self.BUZZER_PIN, self.BUZZER_DUTY_SAFE)

    def handleBuzzer(self, currentMillis):
        if self.beepRemaining <= 0:
            if self.isBeepOn:
                self.stopBuzzer()
            return

        interval = self.beepOnTime if self.isBeepOn else 80
        if currentMillis - self.lastBeepTime >= interval:
            self.lastBeepTime = currentMillis
            if self.isBeepOn:
                self.isBeepOn = False
                self.ledcWrite(self.BUZZER_PIN, 0)
                self.digitalWrite(self.BUZZER_PIN, 0)
                self.beepRemaining -= 1
            else:
                if self.beepRemaining > 0:
                    self.isBeepOn = True
                    self.ledcAttach(self.BUZZER_PIN, self.beepFreq, 8)
                    self.ledcWrite(self.BUZZER_PIN, self.BUZZER_DUTY_SAFE)


def test_buzzer_dismiss_when_on():
    bz = MockBuzzerHardware()
    bz.startBeep(5, 200, 3000, 1000)
    assert bz.isBeepOn is True
    assert bz.pwm_duty == 32
    assert bz.beepRemaining == 5

    # User bấm nút tắt khi còi đang ON
    bz.stopBuzzer()
    bz.handleBuzzer(1050)
    assert bz.isBeepOn is False
    assert bz.beepRemaining == 0
    assert bz.pwm_duty == 0
    assert bz.gpio_level == 0
    print("[PASS] Test Buzzer: Dismiss when ON -> Output shut down to 0V")


def test_buzzer_dismiss_between_beeps():
    bz = MockBuzzerHardware()
    bz.startBeep(5, 200, 3000, 1000)
    # Het nhip 1: chuyen sang nghi giua 2 nhip (isBeepOn == False)
    bz.handleBuzzer(1200)
    assert bz.isBeepOn is False
    assert bz.beepRemaining == 4

    # User bam nut tat khi dang nghi giua 2 nhip
    bz.stopBuzzer()
    bz.handleBuzzer(1250)
    assert bz.isBeepOn is False
    assert bz.beepRemaining == 0
    assert bz.pwm_duty == 0
    print("[PASS] Test Buzzer: Dismiss during quiet interval -> Stays completely off")


def test_buzzer_new_beep_after_dismiss():
    bz = MockBuzzerHardware()
    bz.startBeep(5, 200, 3000, 1000)
    bz.stopBuzzer()
    assert bz.pwm_duty == 0

    # Khoi dong chu ky beep moi
    bz.startBeep(2, 60, 2000, 1500)
    assert bz.isBeepOn is True
    assert bz.beepRemaining == 2
    assert bz.pwm_duty == 32
    assert bz.beepFreq == 2000
    print("[PASS] Test Buzzer: Start new beep after forced dismissal successful")


# ==============================================================================
# 2. TEST MILLIS OVERFLOW / WRAP-AROUND
# ==============================================================================
def uint32_sub(a, b):
    return (a - b) & 0xFFFFFFFF


def test_millis_overflow_simulation():
    # Gia lap millis() o moc 49.7 ngay: 0xFFFFFF00 (4,294,967,040 ms)
    # Thong bao kich hoat tai 0xFFFFFF00 voi thoi han 2500 ms
    # Sau 2500 ms, bo dem tran qua 0 va dat (0xFFFFFF00 + 2500) & 0xFFFFFFFF
    notifStartTime = 0xFFFFFF00
    DURATION = 2500

    # Tinh huong 1: Moi troi qua 1000 ms
    cur_millis_1 = (notifStartTime + 1000) & 0xFFFFFFFF
    elapsed_1 = uint32_sub(cur_millis_1, notifStartTime)
    assert elapsed_1 == 1000
    notif_active_1 = not (elapsed_1 >= DURATION)
    assert notif_active_1 is True, "Thong bao KHONG duoc tat sau 1s"

    # Tinh huong 2: Troi qua 2499 ms (millis wrap-around qua 0)
    cur_millis_2 = (notifStartTime + 2499) & 0xFFFFFFFF
    elapsed_2 = uint32_sub(cur_millis_2, notifStartTime)
    assert elapsed_2 == 2499
    notif_active_2 = not (elapsed_2 >= DURATION)
    assert notif_active_2 is True, "Thong bao KHONG duoc tat truoc 2500ms du da tran so"

    # Tinh huong 3: Troi qua dung 2500 ms
    cur_millis_3 = (notifStartTime + 2500) & 0xFFFFFFFF
    elapsed_3 = uint32_sub(cur_millis_3, notifStartTime)
    assert elapsed_3 == 2500
    notif_active_3 = not (elapsed_3 >= DURATION)
    assert notif_active_3 is False, "Thong bao PHAI tat chinh xac tai moc 2500ms"
    print("[PASS] Test Millis Overflow: Unsigned uint32 subtraction is immune to 49.7 days wrap-around")


# ==============================================================================
# 3. TEST RTC VALIDITY CHECK FOR ALARM
# ==============================================================================
def should_fire_alarm(rtcFound, lostPower, isValid, alarmEnabled, alarmHour, alarmMinute, nowHour, nowMinute, lastFired):
    if not rtcFound:
        return False
    if not isValid:
        return False
    if lostPower:
        return False
    if not (alarmEnabled and alarmHour >= 0 and alarmMinute >= 0):
        return False
    if nowHour == alarmHour and nowMinute == alarmMinute:
        if lastFired != nowMinute:
            return True
    return False


def test_alarm_rtc_checks():
    # Case 1: RTC khong tim thay (rtcFound == False)
    assert should_fire_alarm(False, False, True, True, 7, 30, 7, 30, -1) is False

    # Case 2: RTC mat nguon, thoi gian chua xac thuc (lostPower == True)
    assert should_fire_alarm(True, True, True, True, 7, 30, 7, 30, -1) is False

    # Case 3: DateTime khong hop le (isValid == False)
    assert should_fire_alarm(True, False, False, True, 7, 30, 7, 30, -1) is False

    # Case 4: RTC binh thuong, dung gio -> Kich hoat
    assert should_fire_alarm(True, False, True, True, 7, 30, 7, 30, -1) is True

    # Case 5: Da kich hoat trong phut nay (lastFired == 30) -> Khong kich hoat lap lai
    assert should_fire_alarm(True, False, True, True, 7, 30, 7, 30, 30) is False
    print("[PASS] Test RTC Alarm: Prevents false alarm triggers when RTC is offline or lost power")


# ==============================================================================
# 4. TEST OFFLINE FIFO QUEUE & BLE ACK
# ==============================================================================
class MockNVSQueue:
    def __init__(self, max_q=5):
        self.MAX_POMO_QUEUE = max_q
        self.storage = {}
        self.pomoQueueCount = 0
        self.pomoQueueHead = 0
        self.pomoQueueTail = 0
        self.waitingForPomoAck = False
        self.currentPomoAckId = ""
        self.bleConnected = False

    def enqueue(self, json_str, session_id):
        if self.pomoQueueCount >= self.MAX_POMO_QUEUE:
            return False  # Reject, khong am tham ghi de
        self.storage[f"pq_item_{self.pomoQueueTail}"] = json_str
        self.storage[f"pq_id_{self.pomoQueueTail}"] = session_id
        self.pomoQueueTail = (self.pomoQueueTail + 1) % self.MAX_POMO_QUEUE
        self.pomoQueueCount += 1
        return True

    def processQueue(self):
        if not self.bleConnected or self.pomoQueueCount <= 0:
            return None
        if self.waitingForPomoAck:
            return None  # Dang cho ACK
        item = self.storage.get(f"pq_item_{self.pomoQueueHead}")
        sid = self.storage.get(f"pq_id_{self.pomoQueueHead}")
        self.currentPomoAckId = sid
        self.waitingForPomoAck = True
        return (sid, item)

    def handleAck(self, ack_session_id):
        if self.pomoQueueCount <= 0:
            return False
        expected_id = self.storage.get(f"pq_id_{self.pomoQueueHead}")
        if ack_session_id and expected_id == ack_session_id:
            del self.storage[f"pq_item_{self.pomoQueueHead}"]
            del self.storage[f"pq_id_{self.pomoQueueHead}"]
            self.pomoQueueHead = (self.pomoQueueHead + 1) % self.MAX_POMO_QUEUE
            self.pomoQueueCount -= 1
            self.waitingForPomoAck = False
            self.currentPomoAckId = ""
            return True
        return False

    def reconnect(self):
        self.bleConnected = True
        self.waitingForPomoAck = False


def test_offline_fifo_and_ack():
    q = MockNVSQueue(max_q=5)
    q.bleConnected = False  # Dien thoai mat ket noi

    # 1. Luu 5 phien lien tiep khi offline
    for i in range(1, 6):
        ok = q.enqueue(f'{{"session":{i}}}', f"session_{i}")
        assert ok is True
    assert q.pomoQueueCount == 5

    # 2. Hang doi day (5/5): Phien thu 6 phai bi tu choi, khong duoc ghi de phien 1
    ok6 = q.enqueue('{"session":6}', "session_6")
    assert ok6 is False, "Hang doi day phai tu choi ghi them"
    assert q.pomoQueueCount == 5
    assert q.storage["pq_id_0"] == "session_1", "Phien 1 khong bi ghi de"
    print("[PASS] Test FIFO: Successfully stored 5 offline sessions & rejected overwrite on full")

    # 3. Ket noi lai BLE
    q.reconnect()

    # 4. Xac nhan FIFO gui dung thu tu tu session_1 den session_5
    sent_order = []
    for expected_i in range(1, 6):
        tx = q.processQueue()
        assert tx is not None
        sid, _ = tx
        assert sid == f"session_{expected_i}", f"Sai thu tu FIFO: nhan {sid}, mong muon session_{expected_i}"
        sent_order.append(sid)

        # ACK sai session_id -> khong duoc xoa phien
        wrong_ack = q.handleAck("wrong_id_xyz")
        assert wrong_ack is False
        assert q.pomoQueueCount == (6 - expected_i)

        # Gia lap ngat ket noi BLE giua chung khi dang cho ACK
        if expected_i == 3:
            q.bleConnected = False
            q.reconnect()
            # Gui lai dung session 3
            tx_retry = q.processQueue()
            assert tx_retry[0] == "session_3"

        # Gui ACK dung
        ok_ack = q.handleAck(f"session_{expected_i}")
        assert ok_ack is True

    assert q.pomoQueueCount == 0
    assert sent_order == [f"session_{i}" for i in range(1, 6)]
    print("[PASS] Test FIFO: Sequential transmission in strict FIFO order, reconnect recovery, invalid ACK rejection")


if __name__ == "__main__":
    print("=== RUNNING FIRMWARE LOGIC TESTS ===")
    test_buzzer_dismiss_when_on()
    test_buzzer_dismiss_between_beeps()
    test_buzzer_new_beep_after_dismiss()
    test_millis_overflow_simulation()
    test_alarm_rtc_checks()
    test_offline_fifo_and_ack()
    print("=== ALL FIRMWARE LOGIC TESTS PASSED! ===")
