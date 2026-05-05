package com.minimalism.focus.backend.db

object AppCategoryMapping {
    val DEFAULT_PRODUCTIVE_APPS = setOf(
        "com.google.android.keep",
        "com.microsoft.todos",
        "com.google.android.apps.docs",
        "com.notion.id",
        "com.todoist"
    )

    val DEFAULT_SOCIAL_APPS = setOf(
        "com.instagram.android",
        "com.facebook.katana",
        "com.twitter.android",
        "com.zhiliaoapp.musically", // TikTok
        "com.snapchat.android"
    )

    val DEFAULT_ENTERTAINMENT_APPS = setOf(
        "com.google.android.youtube",
        "com.netflix.mediaclient",
        "tv.twitch.android.app",
        "com.spotify.music"
    )
}
