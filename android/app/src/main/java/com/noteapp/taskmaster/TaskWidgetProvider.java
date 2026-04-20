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

    // home_widget 插件使用的 SharedPreferences 文件名
    private static final String PREFS_NAME = "HomeWidgetPreferences";
    private static final String TASKS_KEY = "widget_tasks";
    private static final String POINTS_KEY = "widget_points";
    private static final String DATE_KEY = "widget_date";
    private static final String PROGRESS_KEY = "widget_progress";

    // 广播 Action
    public static final String ACTION_TOGGLE_TASK = "com.noteapp.taskmaster.TOGGLE_TASK";
    public static final String EXTRA_TASK_INDEX = "task_index";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "onUpdate called with " + appWidgetIds.length + " widgets");
        }
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId);
        }
    }

    static void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "updateAppWidget called for widget ID: " + appWidgetId);
        }
        try {
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.task_widget);
            if (BuildConfig.DEBUG) {
                Log.d(TAG, "Created RemoteViews");
            }

            // 从SharedPreferences读取数据
            SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            String tasksJson = prefs.getString(TASKS_KEY, "[]");
            String points = prefs.getString(POINTS_KEY, "0");
            String date = prefs.getString(DATE_KEY, "今日任务");
            String progress = prefs.getString(PROGRESS_KEY, "0/0 完成");

            if (BuildConfig.DEBUG) {
                Log.d(TAG, "Read data from SharedPreferences:");
                Log.d(TAG, "Tasks: " + tasksJson);
                Log.d(TAG, "Points: " + points);
                Log.d(TAG, "Date: " + date);
                Log.d(TAG, "Progress: " + progress);
            }

            // 设置日期和积分
            views.setTextViewText(R.id.widget_date, date);
            views.setTextViewText(R.id.widget_points, "★ " + points);
            views.setTextViewText(R.id.widget_progress, progress);
            if (BuildConfig.DEBUG) {
                Log.d(TAG, "Set text views");
            }

            // 隐藏所有任务项
            for (int i = 1; i <= 5; i++) {
                int taskLayoutId = context.getResources().getIdentifier(
                        "widget_task_" + i, "id", context.getPackageName());
                if (taskLayoutId != 0) {
                    views.setViewVisibility(taskLayoutId, android.view.View.GONE);
                }
            }

            // 解析并显示任务
            try {
                JSONArray tasks = new JSONArray(tasksJson);
                int taskCount = tasks.length();
                if (BuildConfig.DEBUG) {
                    Log.d(TAG, "Task count: " + taskCount);
                }

                // 显示任务或空状态
                if (taskCount == 0) {
                    if (BuildConfig.DEBUG) {
                        Log.d(TAG, "Showing empty state");
                    }
                    views.setViewVisibility(R.id.widget_task_list, android.view.View.GONE);
                    views.setViewVisibility(R.id.widget_empty, android.view.View.VISIBLE);
                } else {
                    if (BuildConfig.DEBUG) {
                        Log.d(TAG, "Showing " + taskCount + " tasks");
                    }
                    views.setViewVisibility(R.id.widget_task_list, android.view.View.VISIBLE);
                    views.setViewVisibility(R.id.widget_empty, android.view.View.GONE);

                    // 显示任务（最多5个）
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

                        if (BuildConfig.DEBUG) {
                            Log.d(TAG, "Task " + i + ": layoutId=" + taskLayoutId + ", textId=" + taskTextId + ", pointsId=" + taskPointsId + ", checkboxId=" + taskCheckboxId);
                        }

                        if (taskLayoutId != 0) {
                            views.setViewVisibility(taskLayoutId, android.view.View.VISIBLE);
                        }

                        // 设置任务标题
                        if (taskTextId != 0) {
                            views.setTextViewText(taskTextId, title);
                            // 根据完成状态设置文字样式
                            if (isOK) {
                                views.setInt(taskTextId, "setPaintFlags",
                                    android.graphics.Paint.STRIKE_THRU_TEXT_FLAG);
                                views.setTextColor(taskTextId, android.graphics.Color.parseColor("#999999"));
                            } else {
                                views.setInt(taskTextId, "setPaintFlags", 0);
                                views.setTextColor(taskTextId, android.graphics.Color.parseColor("#333333"));
                            }
                        }

                        // 设置积分
                        if (taskPointsId != 0) {
                            if (rewardPoints > 0) {
                                views.setTextViewText(taskPointsId, "+" + rewardPoints);
                                views.setViewVisibility(taskPointsId, android.view.View.VISIBLE);
                            } else {
                                views.setViewVisibility(taskPointsId, android.view.View.GONE);
                            }
                        }

                        // 设置复选框图标和点击事件
                        if (taskCheckboxId != 0) {
                            // 设置复选框图标
                            int checkboxIcon = isOK ? R.drawable.ic_checkbox_checked : R.drawable.ic_checkbox_unchecked;
                            views.setImageViewResource(taskCheckboxId, checkboxIcon);

                            // 设置点击事件 - 发送广播切换任务状态
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

            // 设置点击事件
            try {
                // 打开应用的 PendingIntent
                Intent openAppIntent = new Intent(context, MainActivity.class);
                openAppIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                PendingIntent openAppPendingIntent = PendingIntent.getActivity(
                        context, 100, openAppIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

                // 为打开应用按钮设置点击事件
                views.setOnClickPendingIntent(R.id.widget_open_app, openAppPendingIntent);
                if (BuildConfig.DEBUG) {
                    Log.d(TAG, "Set click intents");
                }
            } catch (Exception e) {
                Log.e(TAG, "Error setting click intent", e);
            }

            // 更新小组件
            if (BuildConfig.DEBUG) {
                Log.d(TAG, "Updating widget with ID: " + appWidgetId);
            }
            appWidgetManager.updateAppWidget(appWidgetId, views);
            if (BuildConfig.DEBUG) {
                Log.d(TAG, "Widget updated successfully");
            }
        } catch (Exception e) {
            Log.e(TAG, "Error in updateAppWidget", e);
        }
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "onReceive called with action: " + intent.getAction());
        }

        // 处理任务切换广播
        if (ACTION_TOGGLE_TASK.equals(intent.getAction())) {
            int taskIndex = intent.getIntExtra(EXTRA_TASK_INDEX, -1);
            int appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID);

            if (taskIndex >= 0) {
                toggleTaskStatus(context, taskIndex);

                // 刷新小组件
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

                // 切换状态
                boolean newStatus = !currentStatus;
                task.put("isOK", newStatus);

                // 更新积分
                if (newStatus) {
                    // 完成任务，增加积分
                    currentPoints += rewardPoints;
                } else {
                    // 取消完成，扣除积分
                    currentPoints -= rewardPoints;
                }

                // 保存更新后的数据
                SharedPreferences.Editor editor = prefs.edit();
                editor.putString(TASKS_KEY, tasks.toString());
                editor.putString(POINTS_KEY, String.valueOf(currentPoints));
                editor.apply();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void onEnabled(Context context) {
        Log.d(TAG, "onEnabled called");
        // 第一个小组件被添加时调用
    }

    @Override
    public void onDisabled(Context context) {
        Log.d(TAG, "onDisabled called");
        // 最后一个小组件被移除时调用
    }
}