# Giữ các lớp native tự viết được gọi qua MethodChannel/EventChannel
-keep class com.exe401.pomosmart.** { *; }

# Flutter Play Core (deferred components) - không dùng nên bỏ qua cảnh báo R8
-dontwarn com.google.android.play.core.**
