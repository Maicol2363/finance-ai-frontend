# JNA's native code looks up Pointer.peer by field name. Preserve JNA classes
# and their members from shrinking/obfuscation for JNI and reflection access.
-keep class com.sun.jna.** { *; }
# Vosk registers native methods through JNA reflection. R8 removed the public
# no-argument org.vosk.Model constructor required by PointerType conversion.
-keep class org.vosk.** { *; }
# JNA ships desktop-only AWT helpers that Android does not provide.
-dontwarn java.awt.**
