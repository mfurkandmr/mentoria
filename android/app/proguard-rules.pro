# Sürüm derlemesinde R8 küçültmesi için ek kurallar.

# flutter_local_notifications: zamanlanmış bildirimler (pomodoro alarmı)
# Gson ile saklanır. Bu kurallar olmadan zonedSchedule sürüm derlemesinde
# "Missing type parameter" hatası verir; alarm kurulamaz ve zil ancak
# uygulama açılınca çalar.
-keep class com.dexterous.** { *; }

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
