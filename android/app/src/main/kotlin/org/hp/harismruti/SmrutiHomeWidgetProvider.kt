package org.hp.harismruti

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class SmrutiHomeWidgetProvider : HomeWidgetProvider() {
    private val rowIds = intArrayOf(
        R.id.widget_row_1,
        R.id.widget_row_2,
        R.id.widget_row_3,
        R.id.widget_row_4,
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val stories = JSONArray(widgetData.getString("smruti_stories", "[]"))
        val refreshHours = widgetData.getInt("smruti_refresh_hours", 1).coerceAtLeast(1)
        val page = (System.currentTimeMillis() / (refreshHours * 3_600_000L)).toInt()

        appWidgetIds.forEach { widgetId ->
            val options = appWidgetManager.getAppWidgetOptions(widgetId)
            val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            val columns = when {
                width < 180 -> 1
                width < 300 -> 2
                else -> 3
            }
            val rows = when {
                height < 135 -> 1
                height < 245 -> 2
                height < 355 -> 3
                else -> 4
            }
            val displayedCount = minOf(columns * rows, stories.length())
            val compactHeight = height < 170
            val views = RemoteViews(context.packageName, R.layout.smruti_home_widget)

            views.setViewVisibility(
                R.id.widget_header,
                if (height < 105) View.GONE else View.VISIBLE,
            )
            views.setTextViewText(
                R.id.widget_heading,
                if (stories.length() == 0) {
                    "HariPrabodham Smruti • Open app to load photos"
                } else {
                    "HariPrabodham Smruti"
                },
            )
            views.setTextViewText(
                R.id.widget_photo_count,
                "$displayedCount ${if (displayedCount == 1) "PHOTO" else "PHOTOS"}",
            )

            val notificationAt = widgetData.getLong("smruti_notification_at", 0L)
            val isNew = System.currentTimeMillis() - notificationAt < 86_400_000L
            var itemIndex = 0

            rowIds.forEachIndexed { rowIndex, rowId ->
                views.removeAllViews(rowId)
                if (rowIndex >= rows || stories.length() == 0) {
                    views.setViewVisibility(rowId, View.GONE)
                    return@forEachIndexed
                }
                views.setViewVisibility(rowId, View.VISIBLE)
                repeat(columns) {
                    if (itemIndex >= displayedCount) return@repeat
                    val story = stories.getJSONObject((page + itemIndex) % stories.length())
                    val tile = RemoteViews(context.packageName, R.layout.smruti_widget_tile)
                    tile.setTextViewText(
                        R.id.story_title,
                        story.optString("title", "Smruti"),
                    )
                    tile.setViewVisibility(
                        R.id.story_title,
                        if (compactHeight) View.GONE else View.VISIBLE,
                    )
                    tile.setViewVisibility(
                        R.id.story_badge,
                        if (itemIndex == 0) View.VISIBLE else View.GONE,
                    )
                    if (itemIndex == 0) {
                        tile.setTextViewText(
                            R.id.story_badge,
                            if (isNew) "NEW" else "LATEST",
                        )
                    }

                    val bitmap = BitmapFactory.decodeFile(story.optString("image"))
                    if (bitmap != null) {
                        tile.setImageViewBitmap(R.id.story_image, widgetBitmap(bitmap))
                    }
                    val launchIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse(story.optString("uri")),
                    )
                    tile.setOnClickPendingIntent(R.id.story_tile, launchIntent)
                    views.addView(rowId, tile)
                    itemIndex++
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        val preferences = context.getSharedPreferences(
            "HomeWidgetPreferences",
            Context.MODE_PRIVATE,
        )
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId), preferences)
    }

    private fun widgetBitmap(source: Bitmap): Bitmap {
        val maxEdge = 420
        if (source.width <= maxEdge && source.height <= maxEdge) return source
        val ratio = minOf(
            maxEdge.toFloat() / source.width,
            maxEdge.toFloat() / source.height,
        )
        return Bitmap.createScaledBitmap(
            source,
            (source.width * ratio).toInt().coerceAtLeast(1),
            (source.height * ratio).toInt().coerceAtLeast(1),
            true,
        )
    }
}
