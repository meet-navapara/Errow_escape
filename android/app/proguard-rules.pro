# Room creates its generated databases (e.g. WorkManager's WorkDatabase_Impl,
# pulled in by the Google Mobile Ads SDK) by reflection. Without these rules R8
# strips the constructor and release builds crash on start with
# "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
