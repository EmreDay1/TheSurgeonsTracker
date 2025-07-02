import { supabase } from '../config/supabase';
import * as Notifications from 'expo-notifications';
import * as Device from 'expo-device';
import { Platform } from 'react-native';

/**
 * Pills service with proper notification setup
 * Based on Expo's recommended notification patterns
 */

// Configure notification handler (same as the example)
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

// Set up proper notification channels and permissions
const setupNotifications = async () => {
  try {
    // Set up Android notification channel
    if (Platform.OS === 'android') {
      await Notifications.setNotificationChannelAsync('pill-reminders', {
        name: 'Pill Reminders',
        importance: Notifications.AndroidImportance.MAX,
        vibrationPattern: [0, 250, 250, 250],
        lightColor: '#FF231F7C',
        sound: 'default',
      });
    }

    // Request permissions
    if (Device.isDevice) {
      const { status: existingStatus } = await Notifications.getPermissionsAsync();
      let finalStatus = existingStatus;
      
      if (existingStatus !== 'granted') {
        const { status } = await Notifications.requestPermissionsAsync();
        finalStatus = status;
      }
      
      if (finalStatus !== 'granted') {
        console.warn('Push notification permissions not granted');
        return false;
      }
      
      console.log('✅ Notification permissions granted');
      return true;
    } else {
      console.warn('Must use physical device for proper notifications');
      return false;
    }
  } catch (error) {
    console.error('Error setting up notifications:', error);
    return false;
  }
};

// Initialize notifications (call this once in your app)
export const initializeNotifications = async () => {
  const permissionsGranted = await setupNotifications();
  
  // Set up notification listeners
  const notificationListener = Notifications.addNotificationReceivedListener(notification => {
    console.log('📱 Notification received:', notification.request.content.title);
  });

  const responseListener = Notifications.addNotificationResponseReceivedListener(response => {
    console.log('📱 Notification tapped:', response.notification.request.content.data);
    
    // Handle notification tap (when user taps the notification)
    const { pillId, pillName, type } = response.notification.request.content.data;
    
    if (type === 'daily_reminder') {
      console.log(`User tapped reminder for: ${pillName}`);
      // You can add logic here to mark pill as taken or navigate to pill screen
    }
  });

  return {
    permissionsGranted,
    cleanup: () => {
      Notifications.removeNotificationSubscription(notificationListener);
      Notifications.removeNotificationSubscription(responseListener);
    }
  };
};

// Get all pills for current user
export const getUserPills = async () => {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      throw new Error('User not authenticated');
    }

    const { data, error } = await supabase
      .from('pills')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false });

    if (error) {
      throw error;
    }

    return data || [];
  } catch (error) {
    console.error('Get user pills failed:', error.message);
    throw error;
  }
};

// Schedule notification with proper setup
const scheduleReliableNotification = async (pill) => {
  try {
    const [hour, minute] = pill.time.split(':').map(Number);
    
    console.log(`📅 Scheduling reliable notification for ${pill.name} at ${hour}:${minute}`);
    
    // Cancel any existing notification
    await Notifications.cancelScheduledNotificationAsync(`pill_${pill.id}`);
    
    // Calculate next occurrence
    const now = new Date();
    const nextTime = new Date();
    nextTime.setHours(hour, minute, 0, 0);
    
    // If time has passed today, schedule for tomorrow
    if (nextTime <= now) {
      nextTime.setDate(nextTime.getDate() + 1);
    }
    
    console.log(`📅 Next notification: ${nextTime.toLocaleString()}`);
    
    // Use date-based trigger (most reliable)
    const notificationId = await Notifications.scheduleNotificationAsync({
      identifier: `pill_${pill.id}`,
      content: {
        title: '💊 İlaç Zamanı!',
        body: `${pill.name} alma zamanı geldi`,
        sound: 'default',
        android: {
          channelId: 'pill-reminders',
          priority: 'max',
          sticky: false,
        },
        data: { 
          pillId: pill.id, 
          pillName: pill.name,
          scheduledTime: pill.time,
          type: 'daily_reminder'
        },
      },
      trigger: nextTime,
    });
    
    console.log(`✅ Notification scheduled: ${notificationId}`);
    
    // Schedule tomorrow's notification as backup
    const tomorrow = new Date(nextTime);
    tomorrow.setDate(tomorrow.getDate() + 1);
    
    await Notifications.scheduleNotificationAsync({
      identifier: `pill_${pill.id}_backup`,
      content: {
        title: '💊 İlaç Zamanı!',
        body: `${pill.name} alma zamanı geldi`,
        sound: 'default',
        android: {
          channelId: 'pill-reminders',
          priority: 'max',
        },
        data: { 
          pillId: pill.id, 
          pillName: pill.name,
          scheduledTime: pill.time,
          type: 'daily_reminder'
        },
      },
      trigger: tomorrow,
    });
    
    console.log(`✅ Backup notification scheduled for ${tomorrow.toLocaleString()}`);
    return true;
    
  } catch (error) {
    console.error(`❌ Failed to schedule notification for ${pill.name}:`, error);
    return false;
  }
};

// Add a new pill
export const addPill = async (pillData) => {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      throw new Error('User not authenticated');
    }

    // Validate time format
    const timeRegex = /^([01]?[0-9]|2[0-3]):[0-5][0-9]$/;
    if (!timeRegex.test(pillData.time)) {
      throw new Error('Invalid time format');
    }

    // Save pill to database
    const newPill = {
      user_id: user.id,
      name: pillData.name.trim(),
      time: pillData.time,
      taken: false,
      created_at: new Date().toISOString()
    };

    const { data, error } = await supabase
      .from('pills')
      .insert([newPill])
      .select()
      .single();

    if (error) {
      throw error;
    }

    console.log(`✅ Pill saved: ${data.name} at ${data.time}`);

    // Try to schedule notification
    const notificationScheduled = await scheduleReliableNotification(data);
    
    if (!notificationScheduled) {
      console.warn('⚠️ Notification scheduling failed, but pill was saved');
    }

    return data;
    
  } catch (error) {
    console.error('Add pill failed:', error.message);
    throw error;
  }
};

// Calculate timing status
const getTimingStatus = (scheduledTime, takenTime) => {
  const [schedHour, schedMin] = scheduledTime.split(':').map(Number);
  
  const scheduled = new Date();
  scheduled.setHours(schedHour, schedMin, 0, 0);
  
  const taken = new Date(takenTime);
  const diffMinutes = Math.round((taken - scheduled) / (1000 * 60));
  
  let status = 'on_time';
  if (diffMinutes > 10) status = 'late';
  else if (diffMinutes < -10) status = 'early';
  
  return { status, minutes: diffMinutes };
};

// Log when pill is taken
export const logPillTaken = async (pillId, scheduledTime) => {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      throw new Error('User not authenticated');
    }

    const takenAt = new Date().toISOString();
    const timing = getTimingStatus(scheduledTime, takenAt);

    // Save log to database
    const { data: logData, error } = await supabase
      .from('pill_logs')
      .insert([{
        pill_id: pillId,
        user_id: user.id,
        taken_at: takenAt,
        scheduled_time: scheduledTime,
        status: timing.status,
        minutes_difference: timing.minutes
      }])
      .select()
      .single();

    if (error) {
      throw error;
    }

    // Show confirmation notification
    const statusText = timing.status === 'on_time' ? 'zamanında' : 
                     timing.status === 'late' ? `${timing.minutes} dk geç` : 
                     `${Math.abs(timing.minutes)} dk erken`;

    await Notifications.scheduleNotificationAsync({
      content: {
        title: '✅ İlaç Alındı',
        body: `${statusText} alındı`,
        sound: 'default',
        android: {
          channelId: 'pill-reminders',
        },
        data: { type: 'confirmation' }
      },
      trigger: null, // Immediate
    });

    return { logData, timing };
    
  } catch (error) {
    console.error('Log pill failed:', error.message);
    throw error;
  }
};

// Update pill status
export const updatePillStatus = async (pillId, taken, scheduledTime) => {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      throw new Error('User not authenticated');
    }

    const updateData = {
      taken: taken,
      updated_at: new Date().toISOString()
    };

    if (taken) {
      updateData.taken_at = new Date().toISOString();
      
      if (scheduledTime) {
        await logPillTaken(pillId, scheduledTime);
      }
    } else {
      updateData.taken_at = null;
    }

    const { data, error } = await supabase
      .from('pills')
      .update(updateData)
      .eq('id', pillId)
      .eq('user_id', user.id)
      .select()
      .single();

    if (error) {
      throw error;
    }

    return data;
    
  } catch (error) {
    console.error('Update pill status failed:', error.message);
    throw error;
  }
};

// Get pill logs
export const getPillLogs = async (pillId) => {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      throw new Error('User not authenticated');
    }

    const { data, error } = await supabase
      .from('pill_logs')
      .select('*')
      .eq('pill_id', pillId)
      .eq('user_id', user.id)
      .order('taken_at', { ascending: false });

    if (error) {
      throw error;
    }

    return data || [];
  } catch (error) {
    console.error('Get pill logs failed:', error.message);
    throw error;
  }
};

// Delete pill
export const deletePill = async (pillId) => {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      throw new Error('User not authenticated');
    }

    // Cancel notifications
    await Notifications.cancelScheduledNotificationAsync(`pill_${pillId}`);
    await Notifications.cancelScheduledNotificationAsync(`pill_${pillId}_backup`);

    // Delete logs
    await supabase
      .from('pill_logs')
      .delete()
      .eq('pill_id', pillId)
      .eq('user_id', user.id);

    // Delete pill
    const { error } = await supabase
      .from('pills')
      .delete()
      .eq('id', pillId)
      .eq('user_id', user.id);

    if (error) {
      throw error;
    }

    return true;
  } catch (error) {
    console.error('Delete pill failed:', error.message);
    throw error;
  }
};

// Reset daily pills
export const resetDailyPills = async () => {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      throw new Error('User not authenticated');
    }

    const { data, error } = await supabase
      .from('pills')
      .update({ 
        taken: false,
        taken_at: null,
        updated_at: new Date().toISOString()
      })
      .eq('user_id', user.id)
      .select();

    if (error) {
      throw error;
    }

    return data || [];
  } catch (error) {
    console.error('Reset daily pills failed:', error.message);
    throw error;
  }
};

// Get today's schedule
export const getTodaySchedule = async () => {
  try {
    const pills = await getUserPills();
    
    return pills.sort((a, b) => {
      const timeA = a.time || '00:00';
      const timeB = b.time || '00:00';
      return timeA.localeCompare(timeB);
    });
  } catch (error) {
    console.error('Get today schedule failed:', error.message);
    throw error;
  }
};

// Get adherence stats
export const getAdherenceStats = async () => {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      throw new Error('User not authenticated');
    }

    const pills = await getUserPills();
    const totalPills = pills.length;

    const today = new Date().toISOString().split('T')[0];
    
    const { data: logs } = await supabase
      .from('pill_logs')
      .select('*')
      .eq('user_id', user.id)
      .gte('taken_at', `${today}T00:00:00.000Z`)
      .lt('taken_at', `${today}T23:59:59.999Z`);

    const todayLogs = logs || [];
    const onTime = todayLogs.filter(log => log.status === 'on_time').length;
    const late = todayLogs.filter(log => log.status === 'late').length;
    const early = todayLogs.filter(log => log.status === 'early').length;
    const taken = onTime + late + early;
    const missed = totalPills - taken;
    const adherenceRate = totalPills > 0 ? Math.round((taken / totalPills) * 100) : 0;

    return {
      total: totalPills,
      taken: taken,
      onTime: onTime,
      late: late,
      early: early,
      missed: missed,
      adherenceRate: adherenceRate
    };
  } catch (error) {
    console.error('Get adherence stats failed:', error.message);
    throw error;
  }
};

// Debug notifications
export const debugNotifications = async () => {
  try {
    const scheduled = await Notifications.getAllScheduledNotificationsAsync();
    console.log('📋 Scheduled notifications:', scheduled.length);
    
    scheduled.forEach((notif, index) => {
      console.log(`${index + 1}. ${notif.identifier}: ${notif.content.title}`);
      console.log(`   Trigger:`, notif.trigger);
    });
    
    return scheduled;
  } catch (error) {
    console.error('Debug notifications failed:', error.message);
    return [];
  }
};

export default {
  initializeNotifications,
  getUserPills,
  addPill,
  updatePillStatus,
  deletePill,
  resetDailyPills,
  getTodaySchedule,
  getAdherenceStats,
  logPillTaken,
  getPillLogs,
  debugNotifications,
};
