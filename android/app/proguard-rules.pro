# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# Google ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# Supabase
-keep class io.supabase.** { *; }

# Sentry
-keep class io.sentry.** { *; }
-keepattributes LineNumberTable,SourceFile
-dontwarn io.sentry.android.fragment.**

# Fix Unsafe API warnings
-dontwarn sun.misc.Unsafe
-dontwarn sun.misc.**

# Keep Flutter plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Prevent stripping of native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep annotation classes
-keepattributes *Annotation*

# Prevent obfuscation of Flutter's generated plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
