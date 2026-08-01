# --- Flutter engine / plugin registrant -------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# --- Google ML Kit text recognition ------------------------------------
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-dontwarn com.google.mlkit.**

# --- Google Mobile Ads (AdMob) ------------------------------------------
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# --- Syncfusion PDF (uses reflection for font/encoding lookups) --------
-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**

# --- Tesseract OCR JNI bridge (Arabic/Urdu offline OCR) ------------------
# Native method signatures and the wrapper class must survive
# obfuscation or the JNI calls silently fail at runtime.
-keep class com.googlecode.tesseract.android.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

# --- CameraX (used by the document scanner) ------------------------------
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# --- Gson / Moshi style reflection used transitively by some plugins ----
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# --- Kotlin metadata (keeps default-argument bridges from vanishing) ---
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# --- General Android component safety ------------------------------------
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
