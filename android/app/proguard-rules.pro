# Preserve metadata commonly used by Flutter plugins.
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeInvisibleAnnotations
-keepattributes AnnotationDefault
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Protect the sqflite Android implementation and plugin entry point.
-keep class com.tekartik.sqflite.** { *; }
-keep interface com.tekartik.sqflite.** { *; }
