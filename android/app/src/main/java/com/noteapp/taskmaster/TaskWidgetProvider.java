package com.noteapp.taskmaster;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.widget.RemoteViews;
import android.util.Log;

import com.noteapp.taskmaster.MainActivity;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class TaskWidgetProvider extends AppWidgetProvider {

    private static final String TAG = "TaskWidgetProvider";

    private static final String PREFS_NAME = "HomeWidgetPreferences";
    private static final String TASKS_KEY = "widget_tasks";
    private static final String POINTS_KEY = "widget_points";
    private static final String DATE_KEY = "widget_date";
    private static final String PROGRESS_KEY = "widget_progress";

    public static final String ACTION_TOGGLE_TASK = "com.noteapp.taskmaster.TOGGLE_TASK";
    public static final String EXTRA_TASK_INDEX = "task_index";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId);
        }
    }

    static void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        try {
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.task_widget);

            SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            String tasksJson = prefs.getString(TASKS_KEY, "[]");
            String points = prefs.getString(POINTS_KEY, "0");
            String date = prefs.getString(DATE_KEY, "今日任务");
            String progress = prefs.getString(PROGRESS_KEY, "0/0 完成");

            views.setTextViewText(R.id.widget_date, date);
            views.setTextViewText(R.id.widget_points, "★ " + points);
            views.setTextViewText(R.id.widget_progress, progress);

            for (int i = 1; i <= 5; i++) {
                int taskLayoutId = context.getResources().getIdentifier(
                        "widget_task_" + i, "id", context.getPackageName());
                if (taskLayoutId != 0) {
                    views.setViewVisibility(taskLayoutId, android.view.View.GONE);
                }
            }

            try {
                JSONArray tasks = new JSONArray(tasksJson);
                int taskCount = tasks.length();

                if (taskCount == 0) {
                    views.setViewVisibility(R.id.widget_task_list, android.view.View.GONE);
                    views.setViewVisibility(R.id.widget_empty, android.view.View.VISIBLE);
                } else {
                    views.setViewVisibility(R.id.widget_task_list, android.view.View.VISIBLE);
                    views.setViewVisibility(R.id.widget_empty, android.view.View.GONE);

                    for (int i = 0; i < Math.min(taskCount, 5); i++) {
                        JSONObject task = tasks.getJSONObject(i);
                        String title = task.optString("title", "无标题");
                        boolean isOK = task.optBoolean("isOK", false);
                        int rewardPoints = task.optInt("rewardPoints", 0);

                        int taskLayoutId = context.getResources().getIdentifier(
                                "widget_task_" + (i + 1), "id", context.getPackageName());
                        int taskTextId = context.getResources().getIdentifier(
                                "widget_task_" + (i + 1) + "_text", "id", context.getPackageName());
                        int taskPointsId = context.getResources().getIdentifier(
                                "widget_task_" + (i + 1) + "_points", "id", context.getPackageName());
                        int taskCheckboxId = context.getResources().getIdentifier(
                                "widget_task_" + (i + 1) + "_checkbox", "id", context.getPackageName());

                        if (taskLayoutId != 0) {
                            views.setViewVisibility(taskLayoutId, android.view.View.VISIBLE);
                        }

                        if (taskTextId != 0) {
                            views.setTextViewText(taskTextId, title);
                            if (isOK) {
                                views.setInt(taskTextId, "setPaintFlags",
                                    android.graphics.Paint.STRIKE_THRU_TEXT_FLAG);
                                views.setTextColor(taskTextId, android.graphics.Color.parseColor("#999999"));
                            } else {
                                views.setInt(taskTextId, "setPaintFlags", 0);
                                views.setTextColor(taskTextId, android.graphics.Color.parseColor("#333333"));
                            }
                        }

                        if (taskPointsId != 0) {
                            if (rewardPoints > 0) {
                                views.setTextViewText(taskPointsId, "+" + rewardPoints);
                                views.setViewVisibility(taskPointsId, android.view.View.VISIBLE);
                            } else {
                                views.setViewVisibility(taskPointsId, android.view.View.GONE);
                            }
                        }

                        if (taskCheckboxId != 0) {
                            int checkboxIcon = isOK ? R.drawable.ic_checkbox_checked : R.drawable.ic_checkbox_unchecked;
                            views.setImageViewResource(taskCheckboxId, checkboxIcon);

                            Intent toggleIntent = new Intent(context, TaskWidgetProvider.class);
                            toggleIntent.setAction(ACTION_TOGGLE_TASK);
                            toggleIntent.putExtra(EXTRA_TASK_INDEX, i);
                            toggleIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);

                            PendingIntent togglePendingIntent = PendingIntent.getBroadcast(
                                    context, i, toggleIntent,
                                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

                            views.setOnClickPendingIntent(taskCheckboxId, togglePendingIntent);
                        }
                    }
                }
            } catch (JSONException e) {
                Log.e(TAG, "Error parsing tasks JSON", e);
                views.setViewVisibility(R.id.widget_task_list, android.view.View.GONE);
                views.setViewVisibility(R.id.widget_empty, android.view.View.VISIBLE);
            }

            try {
                Intent openAppIntent = new Intent(context, MainActivity.class);
                openAppIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                PendingIntent openAppPendingIntent = PendingIntent.getActivity(
                        context, 100, openAppIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

                views.setOnClickPendingIntent(R.id.widget_open_app, openAppPendingIntent);
            } catch (Exception e) {
                Log.e(TAG, "Error setting click intent", e);
            }

            appWidgetManager.updateAppWidget(appWidgetId, views);
        } catch (Exception e) {
            Log.e(TAG, "Error in updateAppWidget", e);
        }
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);

        if (ACTION_TOGGLE_TASK.equals(intent.getAction())) {
            int taskIndex = intent.getIntExtra(EXTRA_TASK_INDEX, -1);
            int appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID);

            if (taskIndex >= 0) {
                toggleTaskStatus(context, taskIndex);

                if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
                    updateAppWidget(context, appWidgetManager, appWidgetId);
                }
            }
        }
    }

    private void toggleTaskStatus(Context context, int taskIndex) {
        try {
            SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            String tasksJson = prefs.getString(TASKS_KEY, "[]");
            int currentPoints = Integer.parseInt(prefs.getString(POINTS_KEY, "0"));

            JSONArray tasks = new JSONArray(tasksJson);

            if (taskIndex < tasks.length()) {
                JSONObject task = tasks.getJSONObject(taskIndex);
                boolean currentStatus = task.optBoolean("isOK", false);
                int rewardPoints = task.optInt("rewardPoints", 0);

                boolean newStatus = !currentStatus;
                task.put("isOK", newStatus);

                if (newStatus) {
                    currentPoints += rewardPoints;
                } else {
                    currentPoints -= rewardPoints;
                }

                SharedPreferences.Editor editor = prefs.edit();
                editor.putString(TASKS_KEY, tasks.toString());
                editor.putString(POINTS_KEY, String.valueOf(currentPoints));
                editor.apply();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
